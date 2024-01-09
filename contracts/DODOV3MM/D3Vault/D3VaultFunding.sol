// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {ICloneFactory} from "../lib/CloneFactory.sol";
import "./D3VaultStorage.sol";
import "../../intf/ID3Oracle.sol";
import "../intf/ID3UserQuota.sol";
import "../intf/ID3PoolQuota.sol";
import "../intf/ID3MM.sol";
import "../intf/IDToken.sol";
import "../intf/ID3RateManager.sol";

/// @title D3VaultFunding
/// @notice This contract defines the fund management of D3Vault.
/// @notice Users (LP) deposit funds into vault to earn interests; D3Pools borrows funds from vault to make market.
/// @notice Part of the borrow interests will become the reserve fund.
/// @notice The borrow interest rate is dynamicly changing with fund utilization ratio, and is caculated by D3RateManager.
/// @notice The fund utilization ratio is defined as U = borrows / (cash + borrows - reserves)
/// @notice Users who deposit funds into vault will receive certain amounts of corresponding dToken. The amount is calculated by the exchange rate.
/// @notice The exchange rate between dToken and underlying token is defined as exchangeRate = (cash + totalBorrows -reserves) / dTokenSupply
/// @notice As time passes, totalBorrows will increase, so does the dToken exchangeRate. That's how users earn interests with dToken.
contract D3VaultFunding is D3VaultStorage {
    using SafeERC20 for IERC20;
    using DecimalMath for uint256;

    // ---------- LP user Fund ----------

    /// @notice user should transfer token to vault before call this function
    /// @param user The address of the user
    /// @param token The address of the token
    /// @return dTokenAmount The amount of dToken minted
    function userDeposit(address user, address token) external nonReentrant allowedToken(token) returns(uint256 dTokenAmount) {
        accrueInterest(token);

        AssetInfo storage info = assetInfo[token];
        uint256 realBalance = IERC20(token).balanceOf(address(this));
        uint256 amount = realBalance  - info.balance;
        require(ID3UserQuota(_USER_QUOTA_).checkQuota(user, token, amount), Errors.EXCEED_QUOTA);
        uint256 exchangeRate = _getExchangeRate(token);
        uint256 totalDToken = IDToken(info.dToken).totalSupply();
        require(totalDToken.mul(exchangeRate) + amount <= info.maxDepositAmount, Errors.EXCEED_MAX_DEPOSIT_AMOUNT);
        dTokenAmount = amount.div(exchangeRate);

        if (totalDToken == 0) {
            // permanently lock a very small amount of dTokens into address(1), which reduces potential issues with rounding, 
            // and also prevents the pool from ever being fully drained
            require(dTokenAmount > DEFAULT_MINIMUM_DTOKEN, Errors.MINIMUM_DTOKEN);
            IDToken(info.dToken).mint(address(1), DEFAULT_MINIMUM_DTOKEN);
            IDToken(info.dToken).mint(user, dTokenAmount - DEFAULT_MINIMUM_DTOKEN);
        } else {
            IDToken(info.dToken).mint(user, dTokenAmount);
        }

        info.balance = realBalance;

        emit UserDeposit(user, token, amount, dTokenAmount);
    }

    /// @notice User withdraw function
    /// @param to The address to receive tokens
    /// @param user The address of the user who pay dTokens
    /// @param token The address of the original token
    /// @param dTokenAmount The amount of dToken to be paid
    /// @return amount The amount of token withdrawn
    function userWithdraw(address to, address user, address token, uint256 dTokenAmount) external nonReentrant allowedToken(token) returns(uint256 amount) {
        accrueInterest(token);
        AssetInfo storage info = assetInfo[token];
        require(dTokenAmount <= IDToken(info.dToken).balanceOf(msg.sender), Errors.DTOKEN_BALANCE_NOT_ENOUGH);

        amount = dTokenAmount.mul(_getExchangeRate(token));
        IDToken(info.dToken).burn(msg.sender, dTokenAmount);
        IERC20(token).safeTransfer(to, amount);
        info.balance = info.balance - amount;

        // used for calculate user withdraw amount
        // this function could be called from d3Proxy, so we need "user" param
        // In the meantime, some users may hope to use this function directly,
        // to prevent these users fill "user" param with wrong addresses,
        // we use "msg.sender" param to check.
        emit UserWithdraw(msg.sender, user, token, amount, dTokenAmount);
    }

    // ---------- Pool Fund ----------

    /// @notice Pool borrow function
    /// @param token The address of the token
    /// @param amount The amount of token to borrow
    function poolBorrow(address token, uint256 amount) external nonReentrant allowedToken(token) onlyPool {
        uint256 quota = ID3PoolQuota(_POOL_QUOTA_).getPoolQuota(msg.sender, token);
        accrueInterest(token);

        AssetInfo storage info = assetInfo[token];
        BorrowRecord storage record = info.borrowRecord[msg.sender];
        uint256 usedQuota = _borrowAmount(record.amount, record.interestIndex, info.borrowIndex); // borrowAmount = record.amount * newIndex / oldIndex
        require(amount + usedQuota <= quota, Errors.EXCEED_QUOTA);
        require(amount <= info.balance - (info.totalReserves - info.withdrawnReserves), Errors.AMOUNT_EXCEED_VAULT_BALANCE);

        uint256 interests = usedQuota - record.amount;

        record.amount = usedQuota + amount;
        record.interestIndex = info.borrowIndex;
        info.totalBorrows = info.totalBorrows + amount;
        info.balance = info.balance - amount; 
        IERC20(token).safeTransfer(msg.sender, amount);

        emit PoolBorrow(msg.sender, token, amount, interests);
    }

    /// @notice Pool repay function
    /// @param token The address of the token
    /// @param amount The amount of token to repay
    function poolRepay(address token, uint256 amount) external nonReentrant allowedToken(token) onlyPool {
        require(!ID3MM(msg.sender).isInLiquidation(), Errors.ALREADY_IN_LIQUIDATION);

        accrueInterest(token);

        AssetInfo storage info = assetInfo[token];
        BorrowRecord storage record = info.borrowRecord[msg.sender];
        uint256 borrows = _borrowAmount(record.amount, record.interestIndex, info.borrowIndex); // borrowAmount = record.amount * newIndex / oldIndex
        require(amount <= borrows, Errors.AMOUNT_EXCEED);

        uint256 interests = borrows - record.amount;

        record.amount = borrows - amount;
        record.interestIndex = info.borrowIndex;
        if (info.totalBorrows < amount) {
            info.totalBorrows = 0;
        } else {
            info.totalBorrows = info.totalBorrows - amount;
        }
        info.balance = info.balance + amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit PoolRepay(msg.sender, token, amount, interests);
    }

    /// @notice Pool repay all the debt of one token
    /// @param token The address of the token
    function poolRepayAll(address token) external nonReentrant allowedToken(token) onlyPool {
        require(!ID3MM(msg.sender).isInLiquidation(), Errors.ALREADY_IN_LIQUIDATION);
        _poolRepayAll(msg.sender, token);
    }

    /// @notice Internal function, pool repay all the debt of one token
    /// @param pool The address of the pool
    /// @param token The address of the token
    function _poolRepayAll(address pool, address token) internal {
        accrueInterest(token);

        AssetInfo storage info = assetInfo[token];
        BorrowRecord storage record = info.borrowRecord[pool];
        uint256 amount = _borrowAmount(record.amount, record.interestIndex, info.borrowIndex); // borrowAmount = record.amount * newIndex / oldIndex

        uint256 interests = amount - record.amount;

        record.amount = 0;
        record.interestIndex = info.borrowIndex;
        if (info.totalBorrows < amount) {
            info.totalBorrows = 0;
        } else {
            info.totalBorrows = info.totalBorrows - amount;
        }
        info.balance = info.balance + amount;
        IERC20(token).safeTransferFrom(pool, address(this), amount);

        emit PoolRepay(pool, token, amount, interests);
    }

    // ---------- Interest ----------

    /// @notice Accrue interest for a token. 
    /// @notice This is just a view function, which will only return the infos after accruing interest. The infos in storage will not be updated. 
    /// @notice Step1: get time past
    /// @notice Step2: get borrow rate
    /// @notice Step3: calculate compound interest rate during the past time
    /// @notice Step4: calculate increased borrows, reserves
    /// @notice Step5: update borrows, reserves, accrual time, borrowIndex
    /// @notice borrowIndex is the accrual interest rate
    /// @param token The address of the token
    /// @return totalBorrowsNew The new total borrows
    /// @return totalReservesNew The new total reserves
    /// @return borrowIndexNew The new borrow index
    /// @return accrualTime The accrual time
    function accrueInterestForRead(address token) public view returns(uint256 totalBorrowsNew, uint256 totalReservesNew, uint256 borrowIndexNew, uint256 accrualTime) {
        AssetInfo storage info = assetInfo[token];

        uint256 currentTime = block.timestamp;
        uint256 deltaTime = currentTime - info.accrualTime;
        if (deltaTime == 0) return(info.totalBorrows, info.totalReserves, info.borrowIndex, currentTime);

        uint256 borrowsPrior = info.totalBorrows;
        uint256 reservesPrior = info.totalReserves;
        uint256 borrowIndexPrior = info.borrowIndex;

        uint256 borrowRate = ID3RateManager(_RATE_MANAGER_).getBorrowRate(token, getUtilizationRatio(token));
        uint256 borrowRatePerSecond = borrowRate / SECONDS_PER_YEAR;
        uint256 compoundInterestRate = getCompoundInterestRate(borrowRatePerSecond, deltaTime);
        totalBorrowsNew = borrowsPrior.mul(compoundInterestRate);
        totalReservesNew = reservesPrior + (totalBorrowsNew - borrowsPrior).mul(info.reserveFactor);
        borrowIndexNew = borrowIndexPrior.mul(compoundInterestRate);

        accrualTime = currentTime;
    }

    /// @notice Accrue interest for a token, change storage
    function accrueInterest(address token) public {
        (assetInfo[token].totalBorrows, assetInfo[token].totalReserves, assetInfo[token].borrowIndex, assetInfo[token].accrualTime) =
        accrueInterestForRead(token);
    }

    /// @notice Accrue interest for all tokens in the token list
    function accrueInterests() public {
        for (uint256 i; i < tokenList.length; i++) {
            address token = tokenList[i];
            accrueInterest(token);
        }
    }

    /// @notice Calculates the compound interest rate.
    /// @dev (1+r)^t = 1 + rt + t*(t-1)*r^2/2! + t*(t-1)*(t-2)*r^3/3! + ... + t*(t-1)...*(t-n+1)*r^n/n!
    /// @param r The interest rate per second (decimals 18).
    /// @param t The total time in seconds.
    function getCompoundInterestRate(uint256 r, uint256 t) public pure returns (uint256) {
        if (t < 1) {
            return 1e18;
        } else if (t < 2) {
            return 1e18 + r * t;
        } else {
            return 1e18 + r * t + r.powFloor(2) * t * (t - 1) / 2;
        }
    }

    // ----------- View ----------

    /// @notice Get the remaining quota of the pool for a specific token
    /// @param pool The address of the pool
    /// @param token The address of the token
    /// @return leftQuota The remaining quota of the pool for the token
    function getPoolLeftQuota(address pool, address token) public view returns(uint256 leftQuota) {
        uint256 quota = ID3PoolQuota(_POOL_QUOTA_).getPoolQuota(pool, token);
        uint256 oldInterestIndex = assetInfo[token].borrowRecord[pool].interestIndex;
        ( , ,uint256 currentInterestIndex, ) = accrueInterestForRead(token);
        uint256 usedQuota = _borrowAmount(assetInfo[token].borrowRecord[pool].amount, oldInterestIndex, currentInterestIndex); // borrowAmount = record.amount * newIndex / oldIndex
        leftQuota = quota > usedQuota ? quota - usedQuota : 0;
    }

    /// @notice Get the utilization ratio of a specific token
    /// @notice U = borrows / (cash + borrows - reserves)
    /// @param token The address of the token
    function getUtilizationRatio(address token) public view returns (uint256) {
        uint256 borrows = getTotalBorrows(token);
        uint256 cash = getCash(token);
        uint256 reserves = getReservesInVault(token);
        if (borrows == 0) return 0;
        if (cash + borrows <= reserves) return 1e18;    // Utilization Ratio is 100%
        return borrows.div(cash + borrows - reserves);
    }

    /// @notice Get the borrow rate of a specific token
    /// @param token The address of the token
    /// @return rate The borrow rate of the token
    function getBorrowRate(address token) public view returns (uint256 rate) {
        rate = ID3RateManager(_RATE_MANAGER_).getBorrowRate(token, getUtilizationRatio(token));
    }

    /// @notice Get the cash (balance) of a specific token
    /// @param token The address of the token
    function getCash(address token) public view returns (uint256) {
        return assetInfo[token].balance;
    }

    /// @notice Get the total borrows of a specific token
    /// @param token The address of the token
    function getTotalBorrows(address token) public view returns (uint256) {
        return assetInfo[token].totalBorrows;
    }

    /// @notice Get the reserves in vault of a specific token
    /// @param token The address of the token
    function getReservesInVault(address token) public view returns (uint256) {
        AssetInfo storage info = assetInfo[token];
        return info.totalReserves - info.withdrawnReserves;
    }

    /// @notice exchangeRate = (cash + totalBorrows -reserves) / dTokenSupply
    /// @notice Make sure accrueInterests or accrueInterest(token) is called before
    /// @param token The address of the token
    function _getExchangeRate(address token) internal view returns (uint256) {
        AssetInfo storage info = assetInfo[token];
        uint256 cash = getCash(token);
        uint256 dTokenSupply = IERC20(info.dToken).totalSupply();
        if (dTokenSupply == 0) { return 1e18; }
        return (cash + info.totalBorrows - (info.totalReserves - info.withdrawnReserves)).div(dTokenSupply);
    } 

    /// @notice Make sure accrueInterests or accrueInterest(token) is called before
    /// @param pool The address of the pool
    /// @param token The address of the token
    /// @return balance The balance of the pool
    /// @return borrows The borrows of the pool
    function _getBalanceAndBorrows(address pool, address token) internal view returns (uint256, uint256) {
        AssetInfo storage info = assetInfo[token];
        BorrowRecord storage record = info.borrowRecord[pool];

        uint256 balance = ID3MM(pool).getTokenReserve(token);
        uint256 borrows = _borrowAmount(record.amount, record.interestIndex, info.borrowIndex); // borrowAmount = record.amount * newIndex / oldIndex

        return (balance, borrows);
    }

    /// @notice Make sure accrueInterests() is called before calling this function
    /// @param pool The address of the pool
    /// @return totalDebt The total debt of the pool
    function _getTotalDebtValue(address pool) internal view returns (uint256 totalDebt) {
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            AssetInfo storage info = assetInfo[token];
            BorrowRecord memory record = info.borrowRecord[pool];
            uint256 borrows = _borrowAmount(record.amount, record.interestIndex, info.borrowIndex); // borrowAmount = record.amount * newIndex / oldIndex
            uint256 price = ID3Oracle(_ORACLE_).getPrice(token);
            totalDebt += borrows.mul(price);
        }
    }

    /// @notice Get the total assets value of a specific pool
    /// @param pool The address of the pool
    /// @return totalValue The total assets value of the pool
    function getTotalAssetsValue(address pool) public view returns (uint256 totalValue) {
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            uint256 price = ID3Oracle(_ORACLE_).getPrice(token);
            totalValue += DecimalMath.mul(ID3MM(pool).getTokenReserve(token), price);
        }
    }

    /// @notice Make sure accrueInterests() is called before
    /// @notice net = balance - borrowed
    /// @notice collateral = sum(min(positive net, maxCollateralAmount）* weight * price)
    /// @notice debt = sum(negative net * weight * price)
    /// @notice collateralRatio = collateral / debt
    /// @param pool The address of the pool
    function _getCollateralRatio(address pool) internal view returns (uint256) {
        uint256 collateral = 0;
        uint256 debt = 0;
        for (uint256 i; i < tokenList.length; i++) {
            address token = tokenList[i];
            AssetInfo storage info = assetInfo[token];

            (uint256 balance, uint256 borrows) = _getBalanceAndBorrows(pool, token);
            uint256 price = ID3Oracle(_ORACLE_).getPrice(token);
            if (balance >= borrows) {
                collateral += min(balance - borrows, info.maxCollateralAmount).mul(info.collateralWeight).mul(price);
            } else {
                debt += (borrows - balance).mul(info.debtWeight).mul(price);
            }
        }
        return _ratioDiv(collateral, debt);
    }

    /// @notice Check if the pool is safe
    /// @param pool The address of the pool
    function checkSafe(address pool) public view returns (bool) {
        return getCollateralRatio(pool) >  1e18 + IM;
    }

    /// @notice Check if the pool is safe to borrow
    /// @param pool The address of the pool
    function checkBorrowSafe(address pool) public view returns (bool) {
        return getCollateralRatioBorrow(pool) > IM;
    }

    /// @notice Check if the pool can be liquidated
    /// @param pool The address of the pool
    function checkCanBeLiquidated(address pool) public view returns (bool) {
        return getCollateralRatio(pool) < 1e18 + MM;
    }

    /// @notice Check if the pool can be liquidated after accrue
    /// @param pool The address of the pool
    function checkCanBeLiquidatedAfterAccrue(address pool) public view returns (bool) {
        return _getCollateralRatio(pool) < 1e18 + MM;
    }

    /// @notice Check if the pool has bad debt
    /// @param pool The address of the pool
    function checkBadDebt(address pool) public view returns (bool) {
        uint256 totalAssetValue = getTotalAssetsValue(pool);
        uint256 totalDebtValue = getTotalDebtValue(pool);
        return totalAssetValue < totalDebtValue;
    }

    /// @notice Check if the pool has bad debt after accrue
    /// @param pool The address of the pool
    function checkBadDebtAfterAccrue(address pool) public view returns (bool) {
        uint256 totalAssetValue = getTotalAssetsValue(pool);
        uint256 totalDebtValue = _getTotalDebtValue(pool);
        return totalAssetValue < totalDebtValue;
    }

    /// @notice Get the minimum value between two numbers
    /// @param a The first number
    /// @param b The second number
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    /// @notice Divide a by b, use this to calculate collateral ratio
    /// @param a The dividend
    /// @param b The divisor
    function _ratioDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 && b == 0) {
            return 1e18;
        } else if (a == 0 && b != 0) {
            return 0;
        } else if (a != 0 && b == 0) {
            return type(uint256).max;
        } else {
            return a.div(b);
        }
    }

    /// @notice Calculate the new borrow amount
    /// @param amount The old borrow amount
    /// @param oldIndex The old index
    /// @param newIndex The new index
    function _borrowAmount(uint256 amount, uint256 oldIndex, uint256 newIndex) internal pure returns (uint256) {
        if (oldIndex == 0) { oldIndex = 1e18; }
        if (oldIndex > newIndex) { oldIndex = newIndex; }
        return amount * newIndex / oldIndex;
    }

    // ======================= Read Only =======================

    /// @notice Get the exchange rate of a specific token
    /// @param token The address of the token
    /// @return exchangeRate The exchange rate of the token
    function getExchangeRate(address token) public view returns(uint256 exchangeRate) {
        (uint256 totalBorrows, uint256 totalReserves, ,) = accrueInterestForRead(token);
        uint256 cash = getCash(token);
        uint256 dTokenSupply = IERC20(assetInfo[token].dToken).totalSupply();
        if (dTokenSupply == 0) { return 1e18; }
        exchangeRate = (cash + totalBorrows - (totalReserves - assetInfo[token].withdrawnReserves)).div(dTokenSupply);
    }

    /// @notice Get the latest borrow index of a specific token
    /// @param token The address of the token
    /// @return borrowIndex The latest borrow index of the token
    function getLatestBorrowIndex(address token) public view returns (uint256 borrowIndex) {
        AssetInfo storage info = assetInfo[token];
        uint256 deltaTime = block.timestamp - info.accrualTime;
        uint256 borrowRate = getBorrowRate(token);
        uint256 borrowRatePerSecond = borrowRate / SECONDS_PER_YEAR;
        uint256 compoundInterestRate = getCompoundInterestRate(borrowRatePerSecond, deltaTime);
        borrowIndex = info.borrowIndex.mul(compoundInterestRate);
    }

    /// @notice Get the borrow amount of the pool for a specific token
    /// @param pool The address of the pool
    /// @param token The address of the token
    /// @return amount The borrow amount of the pool for the token
    function getPoolBorrowAmount(address pool, address token) public view returns (uint256 amount) {
        BorrowRecord storage record = assetInfo[token].borrowRecord[pool];
        uint256 borrowIndex = getLatestBorrowIndex(token);
        amount = _borrowAmount(record.amount, record.interestIndex, borrowIndex); // borrowAmount = record.amount * newIndex / oldIndex
    }

    /// @notice Get the total debt value of a specific pool
    /// @param pool The address of the pool
    /// @return totalDebt The total debt value of the pool
    function getTotalDebtValue(address pool) public view returns (uint256 totalDebt) {
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            uint256 borrowAmount = getPoolBorrowAmount(pool, token);
            uint256 price = ID3Oracle(_ORACLE_).getPrice(token);
            totalDebt += borrowAmount.mul(price);
        }
    }

    /// @notice Get the balance and borrows of the pool for a specific token
    /// @param pool The address of the pool
    /// @param token The address of the token
    /// @return balance The balance of the pool for the token
    /// @return borrows The borrows of the pool for the token
    function getBalanceAndBorrows(address pool, address token) public view returns (uint256, uint256) {
        uint256 balance = ID3MM(pool).getTokenReserve(token);
        uint256 borrows = getPoolBorrowAmount(pool, token);
        return (balance, borrows);
    }

    /// @notice Get the collateral ratio of a specific pool
    /// @param pool The address of the pool
    function getCollateralRatio(address pool) public view returns (uint256) {
        uint256 collateral = 0;
        uint256 debt = 0;
        for (uint256 i; i < tokenList.length; i++) {
            address token = tokenList[i];
            AssetInfo storage info = assetInfo[token];

            (uint256 balance, uint256 borrows) = getBalanceAndBorrows(pool, token);
            uint256 price = ID3Oracle(_ORACLE_).getPrice(token);
            
            if (balance >= borrows) {
                collateral += min(balance - borrows, info.maxCollateralAmount).mul(info.collateralWeight).mul(price);
            } else {
                debt += (borrows - balance).mul(info.debtWeight).mul(price);
            }
        }
        return _ratioDiv(collateral, debt);
    }
    
    /// @notice Get the collateral ratio borrow of a specific pool
    /// @notice collateralRatioBorrow = ∑[min(maxCollateralAmount，balance - borrows）] / ∑borrows
    /// @param pool The address of the pool
    function getCollateralRatioBorrow(address pool) public view returns (uint256) {
        uint256 balanceSumPositive = 0;
        uint256 balanceSumNegative = 0;
        uint256 borrowedSum = 0;
        for (uint256 i; i < tokenList.length; i++) {
            address token = tokenList[i];

            (uint256 balance, uint256 borrows) = getBalanceAndBorrows(pool, token);
            uint256 price = ID3Oracle(_ORACLE_).getPrice(token);

            if (balance >= borrows) {
                balanceSumPositive += min(balance - borrows, assetInfo[token].maxCollateralAmount).mul(price);
            } else {
                balanceSumNegative += (borrows - balance).mul(price);
            }

            borrowedSum += borrows.mul(price);
        }
        
        uint256 balanceSum = balanceSumPositive < balanceSumNegative ? 0 : balanceSumPositive - balanceSumNegative;
        return _ratioDiv(balanceSum, borrowedSum);
    }

    /// @notice Get the cumulative borrow rate and the current amount of the pool for a specific token
    /// @param pool The address of the pool
    /// @param token The address of the token
    /// @return cumulativeRate The cumulative borrow rate of the pool for the token
    /// @return currentAmount The current amount of the pool for the token
    function getCumulativeBorrowRate(address pool, address token) external view returns (uint256 cumulativeRate, uint256 currentAmount) {
        BorrowRecord storage record = assetInfo[token].borrowRecord[pool];
        uint256 borrowIndex = getLatestBorrowIndex(token);
        cumulativeRate = borrowIndex.div(record.interestIndex == 0 ? 1e18 : record.interestIndex);
        currentAmount = record.amount;
    }
}
