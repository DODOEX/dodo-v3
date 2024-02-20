// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "./D3VaultFunding.sol";
import "./D3VaultLiquidation.sol";

/// @title D3Vault
/// @notice This contract inherits from D3VaultFunding and D3VaultLiquidation, with more setting and view functions.
contract D3Vault is D3VaultFunding, D3VaultLiquidation {
    using SafeERC20 for IERC20;
    using DecimalMath for uint256;

    // ---------- Setting ----------

    /// @notice Register a pool by factory
    /// @param pool The address of the pool
    function addD3PoolByFactory(address pool) external onlyFactory {
        if (allPoolAddrMap[pool] == true) revert Errors.D3VaultPoolAlreadyAdded();
        allPoolAddrMap[pool] = true;
        address creator = ID3MM(pool)._CREATOR_();
        creatorPoolMap[creator].push(pool);
        emit AddPool(pool);
    }

    /// @notice Register a pool by owner
    /// @param pool The address of the pool
    function addD3Pool(address pool) external onlyOwner {
        if (allPoolAddrMap[pool] == true) revert Errors.D3VaultPoolAlreadyAdded();
        allPoolAddrMap[pool] = true;
        address creator = ID3MM(pool)._CREATOR_();
        creatorPoolMap[creator].push(pool);
        emit AddPool(pool);
    }

    // ================= Remove Pool Steps ===================
    
    /// @notice Unregister a pool by owner
    /// @notice When removing a pool
    /// @notice if the pool has enough assets to repay all borrows, we can just repay:
    /// @notice removeD3Pool() -> pendingRemovePoolRepayAll(token) -> finishPoolRemove()
    /// @notice if not, should go through liquidation process by DODO before repaying token:
    /// @notice removeD3Pool() -> liquidateByDODO() -> pendingRemovePoolRepayAll(token) -> finishPoolRemove()
    /// @notice if the pool has bad debt, then should go through normal liquidation process instead of repaying token
    /// @notice startLiquidation() -> liquidateByDODO() -> finishLiquidation()
    /// @notice if the pool doesn't have borrows, we just need two steps:
    /// @notice removeD3Pool() -> finishPoolRemove()
    /// @param pool The address of the pool
    function removeD3Pool(address pool) external onlyOwner {
        if (_PENDING_REMOVE_POOL_ != address(0)) revert Errors.D3VaultHasPoolPendingRemove();
        if (allPoolAddrMap[pool] == false) revert Errors.D3VaultPoolNotAdded();
        ID3MM(pool).startLiquidation();

        allPoolAddrMap[pool] = false;
        _PENDING_REMOVE_POOL_ = pool;
        address creator = ID3MM(pool)._CREATOR_();
        address[] memory poolList = creatorPoolMap[creator];
        for (uint256 i = 0; i < poolList.length; i++) {
            if (poolList[i] == pool) {
                poolList[i] = poolList[poolList.length - 1];
                creatorPoolMap[creator] = poolList;
                creatorPoolMap[creator].pop();
                break;
            }
        }
    }

    /// @notice The pending-remove pool repay all the debt of one specific token
    /// @param token The address of the token
    function pendingRemovePoolRepayAll(address token) external onlyOwner {
        _poolRepayAll(_PENDING_REMOVE_POOL_, token);
        ID3MM(_PENDING_REMOVE_POOL_).updateReserveByVault(token);
    }

    /// @notice Finish removing the pool
    function finishPoolRemove() external onlyOwner {
        ID3MM(_PENDING_REMOVE_POOL_).finishLiquidation();
        emit RemovePool(_PENDING_REMOVE_POOL_);
        _PENDING_REMOVE_POOL_ = address(0);
    }

    // ====================================================

    /// @notice Set the clone factory
    /// @param cloneFactory The address of the clone factory
    function setCloneFactory(address cloneFactory) external onlyOwner {
        _CLONE_FACTORY_ = cloneFactory;
        emit SetCloneFactory(cloneFactory);
    }

    /// @notice Set the new D3Factory address
    /// @param newFactory The address of the new factory
    function setNewD3Factory(address newFactory) external onlyOwner {
        _D3_FACTORY_ = newFactory;
        emit SetD3Factory(newFactory);
    }

    /// @notice Set the new D3UserQuota
    /// @param newQuota The address of the new D3UserQuota
    function setNewD3UserQuota(address newQuota) external onlyOwner {
        _USER_QUOTA_ = newQuota;
        emit SetD3UserQuota(newQuota);
    }

    /// @notice Set the new D3PoolQuota
    /// @param newQuota The address of the new D3PoolQuota
    function setNewD3PoolQuota(address newQuota) external onlyOwner {
        _POOL_QUOTA_ = newQuota;
        emit SetD3PoolQuota(newQuota);
    }

    /// @notice Set the new oracle
    /// @param newOracle The address of the new oracle
    function setNewOracle(address newOracle) external onlyOwner {
        _ORACLE_ = newOracle;
        emit SetOracle(newOracle);
    }

    /// @notice Set the new rate manager
    /// @param newRateManager The address of the new rate manager
    function setNewRateManager(address newRateManager) external onlyOwner {
        _RATE_MANAGER_ = newRateManager;
        emit SetRateManager(newRateManager);
    }

    /// @notice Set the maintainer
    /// @param maintainer The address of the maintainer
    function setMaintainer(address maintainer) external onlyOwner {
        _MAINTAINER_ = maintainer;
        emit SetMaintainer(maintainer);
    }

    /// @notice Set the IM
    /// @param newIM The new IM
    function setIM(uint256 newIM) external onlyOwner {
        IM = newIM;
        emit SetIM(newIM);
    }

    /// @notice Set the MM
    /// @param newMM The new MM
    function setMM(uint256 newMM) external onlyOwner {
        MM = newMM;
        emit SetMM(newMM);
    }

    /// @notice Set the DISCOUNT
    /// @param discount The new DISCOUNT
    function setDiscount(uint256 discount) external onlyOwner {
        DISCOUNT = discount;
        emit SetDiscount(discount);
    }

    /// @notice Set the DToken template
    /// @param dTokenTemplate The address of the DToken template
    function setDTokenTemplate(address dTokenTemplate) external onlyOwner {
        _D3TOKEN_LOGIC_ = dTokenTemplate;
        emit SetDTokenTemplate(dTokenTemplate);
    }

    /// @notice Add a router
    /// @param router The address of the router
    function addRouter(address router) external onlyOwner {
        allowedRouter[router] = true;
        emit AddRouter(router);
    }

    /// @notice Remove a router
    /// @param router The address of the router
    function removeRouter(address router) external onlyOwner {
        allowedRouter[router] = false;
        emit RemoveRouter(router);
    }

    /// @notice Add a liquidator
    /// @param liquidator The address of the liquidator
    function addLiquidator(address liquidator) external onlyOwner {
        allowedLiquidator[liquidator] = true;
        emit AddLiquidator(liquidator);
    }

    /// @notice Remove a liquidator
    /// @param liquidator The address of the liquidator
    function removeLiquidator(address liquidator) external onlyOwner {
        allowedLiquidator[liquidator] = false;
        emit RemoveLiquidator(liquidator);
    }

    /// @notice Add a new token
    /// @param token The address of the token
    /// @param maxDeposit The maximum deposit amount
    /// @param maxCollateral The maximum collateral amount
    /// @param collateralWeight The weight of the collateral
    /// @param debtWeight The weight of the debt
    /// @param reserveFactor The reserve factor
    function addNewToken(
        address token,
        uint256 maxDeposit,
        uint256 maxCollateral,
        uint256 collateralWeight,
        uint256 debtWeight,
        uint256 reserveFactor
    ) external onlyOwner {
        if (tokens[token]) revert Errors.D3VaultTokenAlreadyExist();
        if (collateralWeight >= 1e18 || debtWeight <= 1e18) revert Errors.D3VaultWrongWeight();
        if (reserveFactor >= 1e18) revert Errors.D3VaultWrongReserveFactor();
        tokens[token] = true;
        tokenList.push(token);
        address dToken = createDToken(token);
        AssetInfo storage info = assetInfo[token];
        info.dToken = dToken;
        info.reserveFactor = reserveFactor;
        info.borrowIndex = 1e18;
        info.accrualTime = block.timestamp;
        info.maxDepositAmount = maxDeposit;
        info.maxCollateralAmount = maxCollateral;
        info.collateralWeight = collateralWeight;
        info.debtWeight = debtWeight;
        emit AddToken(token);
    }

    /// @notice Create a DToken
    /// @param token The address of the token
    function createDToken(address token) internal returns (address) {
        address d3Token = ICloneFactory(_CLONE_FACTORY_).clone(_D3TOKEN_LOGIC_);
        IDToken(d3Token).init(token, address(this));
        return d3Token;
    }

    /// @notice Set a token
    /// @param token The address of the token
    /// @param maxDeposit The maximum deposit amount
    /// @param maxCollateral The maximum collateral amount
    /// @param collateralWeight The weight of the collateral
    /// @param debtWeight The weight of the debt
    /// @param reserveFactor The reserve factor
    function setToken(
        address token,
        uint256 maxDeposit,
        uint256 maxCollateral,
        uint256 collateralWeight,
        uint256 debtWeight,
        uint256 reserveFactor
    ) external onlyOwner {
        if (!tokens[token]) revert Errors.D3VaultTokenNotExist();
        if (collateralWeight >= 1e18 || debtWeight <= 1e18) revert Errors.D3VaultWrongWeight();
        if (reserveFactor >= 1e18) revert Errors.D3VaultWrongReserveFactor();
        AssetInfo storage info = assetInfo[token];
        info.maxDepositAmount = maxDeposit;
        info.maxCollateralAmount = maxCollateral;
        info.collateralWeight = collateralWeight;
        info.debtWeight = debtWeight;
        info.reserveFactor = reserveFactor;
        emit SetToken(token);
    }

    /// @notice Withdraw reserves by owner
    /// @param token The address of the token
    /// @param amount The amount to withdraw
    function withdrawReserves(address token, uint256 amount) external nonReentrant allowedToken(token) onlyOwner {
        if (_MAINTAINER_ == address(0)) revert Errors.D3VaultMaintainerNotSet();
        accrueInterest(token);
        AssetInfo storage info = assetInfo[token];
        uint256 totalReserves = info.totalReserves;
        uint256 withdrawnReserves = info.withdrawnReserves;
        if (amount > totalReserves - withdrawnReserves) revert Errors.D3VaultWithdrawAmountExceed();
        info.withdrawnReserves = info.withdrawnReserves + amount;
        info.balance = info.balance - amount;
        IERC20(token).safeTransfer(_MAINTAINER_, amount);
        emit WithdrawReserves(token, amount);
    }

    /// @notice If someone directly transfer large amounts of a token into vault, may block the userDeposit() function
    /// @notice Owner can use this function to transfer out the token to unblock deposition.
    // function withdrawLeft(address token) external nonReentrant allowedToken(token) onlyOwner {
    //     require(_MAINTAINER_ != address(0), Errors.MAINTAINER_NOT_SET);
    //     AssetInfo storage info = assetInfo[token];
    //     uint256 balance = IERC20(token).balanceOf(address(this));
    //     if (balance > info.balance) {
    //         IERC20(token).safeTransfer(_MAINTAINER_, balance - info.balance);
    //     }
    // }

    // ---------- View ----------

    /// @notice Get the asset info
    /// @param token The address of the token
    /// @return dToken The address of the DToken
    /// @return totalBorrows The total borrows
    /// @return totalReserves The total reserves
    /// @return reserveFactor The reserve factor
    /// @return borrowIndex The borrow index
    /// @return accrualTime The accrual time
    /// @return maxDepositAmount The maximum deposit amount
    /// @return collateralWeight The weight of the collateral
    /// @return debtWeight The weight of the debt
    /// @return withdrawnReserves The withdrawn reserves
    /// @return balance The balance
    function getAssetInfo(address token)
        external
        view
        returns (
            address dToken,
            uint256 totalBorrows,
            uint256 totalReserves,
            uint256 reserveFactor,
            uint256 borrowIndex,
            uint256 accrualTime,
            uint256 maxDepositAmount,
            uint256 collateralWeight,
            uint256 debtWeight,
            uint256 withdrawnReserves,
            uint256 balance
        )
    {
        AssetInfo storage info = assetInfo[token];
        balance = info.balance;
        dToken = info.dToken;
        totalBorrows = info.totalBorrows;
        totalReserves = info.totalReserves;
        reserveFactor = info.reserveFactor;
        borrowIndex = info.borrowIndex;
        accrualTime = info.accrualTime;
        maxDepositAmount = info.maxDepositAmount;
        collateralWeight = info.collateralWeight;
        debtWeight = info.debtWeight;
        withdrawnReserves = info.withdrawnReserves;
    }

    /// @notice Get the IM and MM
    function getIMMM() external view returns (uint256, uint256) {
        return (IM, MM);
    }

    /// @notice Get the token list
    function getTokenList() external view returns (address[] memory) {
        return tokenList;
    }
}
