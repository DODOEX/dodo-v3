// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "./D3VaultFunding.sol";

contract D3VaultLiquidation is D3VaultFunding {
    using SafeERC20 for IERC20;
    using DecimalMath for uint256;

    function isPositiveNetWorthAsset(address pool, address token) internal view returns (bool) {
        (uint256 balance, uint256 borrows) = _getBalanceAndBorrows(pool, token);
        return balance >= borrows;
    }

    function getPositiveNetWorthAsset(address pool, address token) internal view returns (uint256) {
        (uint256 balance, uint256 borrows) = _getBalanceAndBorrows(pool, token);
        if (balance > borrows) {
            return balance - borrows;
        } else {
            return 0;
        }
    }

    /// @notice public liquidate function, repay pool negative worth token and get collateral tokens with discount
    /// @param pool pool address, must be in belowMM
    /// @param collateral pool collateral, any positive worth token pool has
    /// @param collateralAmount collateral amount liquidator claim
    /// @param debt pool debt, any negative worth token pool has
    /// @param debtToCover debt amount liquidator repay
    function liquidate(
        address pool,
        address collateral,
        uint256 collateralAmount,
        address debt,
        uint256 debtToCover
    ) external nonReentrant {
        accrueInterests();

        if (ID3MM(pool).isInLiquidation()) revert Errors.D3VaultAlreadyInLiquidation();
        if (checkBadDebtAfterAccrue(pool)) revert Errors.D3VaultHasBadDebt();
        if (!checkCanBeLiquidatedAfterAccrue(pool)) revert Errors.D3VaultCannotBeLiquidated();
        if (!isPositiveNetWorthAsset(pool, collateral)) revert Errors.D3VaultInvalidCollateralToken();
        if (isPositiveNetWorthAsset(pool, debt)) revert Errors.D3VaultInvalidDebtToken();
        if (getPositiveNetWorthAsset(pool, collateral) < collateralAmount) revert Errors.D3VaultCollateralAmountExceed();
        
        uint256 collateralTokenPrice = ID3Oracle(_ORACLE_).getPrice(collateral);
        uint256 debtTokenPrice = ID3Oracle(_ORACLE_).getPrice(debt);
        uint256 collateralAmountMax = debtToCover.mul(debtTokenPrice).div(collateralTokenPrice.mul(DISCOUNT));
        if (collateralAmount > collateralAmountMax) revert Errors.D3VaultCollateralAmountExceed();

        AssetInfo storage info = assetInfo[debt];
        BorrowRecord storage record = info.borrowRecord[pool];
        uint256 borrows = _borrowAmount(record.amount, record.interestIndex, info.borrowIndex); // borrowAmount = record.amount * newIndex / oldIndex
        if (debtToCover > borrows) revert Errors.D3VaultDebtToCoverExceed();
        IERC20(debt).safeTransferFrom(msg.sender, address(this), debtToCover);
        
        if (info.totalBorrows < debtToCover) {
            info.totalBorrows = 0;
        } else {
            info.totalBorrows = info.totalBorrows - debtToCover;
        }
        info.balance = info.balance + debtToCover;

        record.amount = borrows - debtToCover;
        record.interestIndex = info.borrowIndex;
        IERC20(collateral).safeTransferFrom(pool, msg.sender, collateralAmount);
        ID3MM(pool).updateReserveByVault(collateral);
        
        emit Liquidate(pool, collateral, collateralAmount, debt, debtToCover);
    }

    // ---------- Liquidate by DODO team ----------
    /// @notice if occuring bad debt, dodo team will start liquidation to balance debt
    function startLiquidation(address pool) external onlyLiquidator nonReentrant {
        accrueInterests();

        if (ID3MM(pool).isInLiquidation()) revert Errors.D3VaultAlreadyInLiquidation();
        if (!checkCanBeLiquidatedAfterAccrue(pool)) revert Errors.D3VaultCannotBeLiquidated();
        ID3MM(pool).startLiquidation();

        uint256 totalAssetValue = getTotalAssetsValue(pool);
        uint256 totalDebtValue = _getTotalDebtValue(pool);
        if (totalAssetValue >= totalDebtValue) revert Errors.D3VaultNoBadDebt();

        uint256 ratio = totalAssetValue.div(totalDebtValue);

        for (uint256 i; i < tokenList.length; i++) {
            address token = tokenList[i];
            AssetInfo storage info = assetInfo[token];
            BorrowRecord storage record = info.borrowRecord[pool];
            uint256 debt = _borrowAmount(record.amount, record.interestIndex, info.borrowIndex).mul(ratio); // borrowAmount = record.amount * newIndex / oldIndex
            liquidationTarget[pool][token] = debt;
        }
        emit StartLiquidation(pool);
    }

    function liquidateByDODO(
        address pool,
        LiquidationOrder calldata order,
        bytes calldata routeData,
        address router
    ) external onlyLiquidator onlyRouter(router) nonReentrant {
        if (!ID3MM(pool).isInLiquidation()) revert Errors.D3VaultNotInLiquidation();

        uint256 toTokenReserve = IERC20(order.toToken).balanceOf(address(this));
        uint256 fromTokenValue = DecimalMath.mul(ID3Oracle(_ORACLE_).getPrice(order.fromToken), order.fromAmount);

        // swap using Route
        {
            IERC20(order.fromToken).safeTransferFrom(pool, router, order.fromAmount);
            (bool success, bytes memory data) = router.call(routeData);
            if (!success) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
        }

        // the transferred-in toToken USD value should not be less than 95% of the transferred-out fromToken
        uint256 receivedToToken = IERC20(order.toToken).balanceOf(address(this)) - toTokenReserve;
        uint256 toTokenValue = DecimalMath.mul(ID3Oracle(_ORACLE_).getPrice(order.toToken), receivedToToken);

        if (toTokenValue < fromTokenValue.mul(DISCOUNT)) revert Errors.D3VaultExceedDiscount();
        IERC20(order.toToken).safeTransfer(pool, receivedToToken);
        ID3MM(pool).updateReserveByVault(order.fromToken);
        ID3MM(pool).updateReserveByVault(order.toToken);
    }

    function finishLiquidation(address pool) external onlyLiquidator nonReentrant {
        if (!ID3MM(pool).isInLiquidation()) revert Errors.D3VaultNotInLiquidation();
        accrueInterests();

        bool hasPositiveBalance;
        bool hasNegativeBalance;
        for (uint256 i; i < tokenList.length; i++) {
            address token = tokenList[i];
            AssetInfo storage info = assetInfo[token];
            uint256 balance = IERC20(token).balanceOf(pool);
            uint256 debt = liquidationTarget[pool][token];
            int256 difference = int256(balance) - int256(debt);
            if (difference > 0) {
                if (hasNegativeBalance) revert Errors.D3VaultLiquidationNotDone();
                hasPositiveBalance = true;
            } else if (difference < 0) {
                if (hasPositiveBalance) revert Errors.D3VaultLiquidationNotDone();
                hasNegativeBalance = true;
                debt = balance; // if balance is less than target amount, just repay with balance
            }

            BorrowRecord storage record = info.borrowRecord[pool];
            uint256 borrows = record.amount;
            if (borrows == 0) continue;

            // note: During liquidation process, the pool's debt will slightly increase due to the generated interests. 
            // The liquidation process will not repay the interests. Thus all dToken holders will share the loss equally.
            uint256 realDebt = _borrowAmount(borrows, record.interestIndex, info.borrowIndex); // borrowAmount = record.amount * newIndex / oldIndex
            IERC20(token).safeTransferFrom(pool, address(this), debt);

            if (info.totalBorrows < realDebt) {
                info.totalBorrows = 0;
            } else {
                info.totalBorrows = info.totalBorrows - realDebt;
            }
            info.balance = info.balance + debt;
            record.amount = 0;
        }

        ID3MM(pool).finishLiquidation();
        emit FinishLiquidation(pool);
    }
}
