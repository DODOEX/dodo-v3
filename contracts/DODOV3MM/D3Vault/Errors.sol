// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

library Errors {
    error D3VaultPoolAlreadyAdded();
    error D3VaultPoolNotAdded();
    error D3VaultHasPoolPendingRemove();
    error D3VaultAmountExceedVaultBalance();
    error D3VaultNotAllowedRouter();
    error D3VaultNotAllowedLiquidator();
    error D3VaultNotPendingRemovePool();
    error D3VaultNotD3Pool();
    error D3VaultNotAllowedToken();
    error D3VaultNotD3Factory();
    error D3VaultTokenAlreadyExist();
    error D3VaultTokenNotExist();
    error D3VaultWrongWeight();
    error D3VaultWrongReserveFactor();
    error D3VaultWithdrawAmountExceed();
    error D3VaultMaintainerNotSet();

    // ---------- funding ----------
    error D3VaultExceedQuota();
    error D3VaultExceedMaxDepositAmount();
    error D3VaultDTokenBalanceNotEnough();
    error D3VaultPoolNotSafe();
    error D3VaultNotEnoughCollateralForBorrow();
    error D3VaultAmountExceed();
    error D3VaultNotRateManager();
    error D3VaultMinimumDToken();

    // ---------- liquidation ----------
    error D3VaultCollateralAmountExceed();
    error D3VaultCannotBeLiquidated();
    error D3VaultInvalidCollateralToken();
    error D3VaultInvalidDebtToken();
    error D3VaultDebtToCoverExceed();
    error D3VaultAlreadyInLiquidation();
    error D3VaultStillUnderMM();
    error D3VaultNoBadDebt();
    error D3VaultNotInLiquidation();
    error D3VaultExceedDiscount();
    error D3VaultLiquidationNotDone();
    error D3VaultHasBadDebt();
}
