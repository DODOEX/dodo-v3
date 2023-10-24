/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";

contract D3VaultLiquidationTest is TestContext {
    function setUp() public {
        contextBasic();

        token2.mint(user1, 1000 ether);
        vm.prank(user1);
        token2.approve(address(d3Vault), type(uint256).max);
    }

    function contextCannotBeLiquidated() public {
        // token2 price: $12
        // token3 price: $1

        // user1 deposit 500 token2 into vault
        vm.prank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);
        mockUserQuota.setUserQuota(user1, address(token2), 1000 ether);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);

        // pool has 100 token3 as collateral, then borrow 10 token2
        // balanceSum = 100 * 1 = 100
        // borrowSum = 10 * 12 = 120
        // collateral ratio borrow = 100 / 120 = 83.3%
        token3.mint(address(d3MM), 100 ether);
        d3MM.updateReserve(address(token3));
        poolBorrow(address(d3MM), address(token2), 10 ether);

        logCollateralRatio(address(d3MM));
    }

    function contextCanBeLiquidated() public {
        contextCannotBeLiquidated();

        // pool has
        // balance: 10 token2, 100 token3
        // borrowed: 10 token2
        // net: 0 token2, 100 token3
        // no negative net, very safe, collateral ratio is MAX
        // now let's remove some token2 from pool
        token2.burn(address(d3MM), 6 ether);
        d3MM.updateReserve(address(token2));
        assertEq(token2.balanceOf(address(d3MM)), 4 ether);

        // now pool has
        // balance: 4 token2, 100 token3
        // borrowed: 10 tokenn2
        // net: -6 token2, +100 token3
        // token2 price: 12, debt weight: 110%
        // token3 price: 1, debt weight: 90%
        // collateralRatio = (100 * 1 * 90%) / (6 * 12 * 110%) = 113.63%
        // vault MM is 20%, 113.63% < 120%, pool can be liquidated
        logCollateralRatio(address(d3MM));
        assertEq(d3Vault.checkCanBeLiquidated(address(d3MM)), true);
    }

    function contextBadDebt() public {
        // user1 deposit 500 token2 into vault
        vm.prank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);
        mockUserQuota.setUserQuota(user1, address(token2), 1000 ether);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);

        // pool has 100 token3 as collateral, then borrow 10 token2
        // balanceSum = 100 * 1 = 100
        // borrowSum = 10 * 12 = 120
        // collateralRatioBorrow = 100 / 120 = 83.3%
        token3.mint(address(d3MM), 100 ether);
        d3MM.updateReserve(address(token3));
        poolBorrow(address(d3MM), address(token2), 10 ether);

        // burn 50 token3 for pool and 5 token 2 for pool
        // now pool has
        // balance: 5 token2, 50 token3
        // borrowed: 10 token2
        // positive net: 50 token3
        // negative net: 5 token2
        // collateralRatio = 50 * 1 * 0.9 / (5 * 12 * 1.1) = 68% < 100%
        token3.burn(address(d3MM), 50 ether);
        d3MM.updateReserve(address(token3));
        token2.burn(address(d3MM), 5 ether);
        d3MM.updateReserve(address(token2));
        assertEq(d3Vault.checkBadDebt(address(d3MM)), true);
    }

    function testCollateralRatioBelowOneHasNoBadDebt() public {
        vm.startPrank(vaultOwner);
        d3Vault.setToken(
            address(token2), // token
            1000 * 1e18, // max deposit
            500 * 1e18, // max collateral
            80 * 1e16, // collateral weight: 80%
            120 * 1e16, // debtWeight: 120%
            10 * 1e16 // reserve factor: 10%
        );

        d3Vault.setToken(
            address(token3), // token
            1000 * 1e18, // max deposit
            500 * 1e18, // max collateral
            80 * 1e16, // collateral weight: 80%
            120 * 1e16, // debtWeight: 120%
            10 * 1e16 // reserve factor: 10%
        );
        vm.stopPrank();

        token2ChainLinkOracle.feedData(1 * 1e18);
        token3ChainLinkOracle.feedData(1 * 1e18);

        // user1 deposit 500 token2 and token3 into vault
        vm.startPrank(user1);
        token2.mint(user1, 1000 ether);
        token2.approve(address(dodoApprove), type(uint256).max);
        mockUserQuota.setUserQuota(user1, address(token2), 1000 ether);
        d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);
        token3.mint(user1, 1000 ether);
        token3.approve(address(dodoApprove), type(uint256).max);
        mockUserQuota.setUserQuota(user1, address(token3), 1000 ether);
        d3Proxy.userDeposit(user1, address(token3), 500 ether, 0);
        vm.stopPrank();

        // pool deposit 1000 token2, 1000 token3
        token2.mint(address(d3MM), 1000 ether);
        d3MM.updateReserve(address(token2));
        token3.mint(address(d3MM), 1000 ether);
        d3MM.updateReserve(address(token3));

        // pool borrow 100 token2 and 100 token3, now pool has:
        // token2 - 100 borrows, 1100 balance
        // token3 - 100 borrows, 1100 balance
        poolBorrow(address(d3MM), address(token2), 100 ether);
        poolBorrow(address(d3MM), address(token3), 100 ether);

        // burn 125 token2 and 1020 token3, now pool has:
        // token2 - 100 borrows, 125 balance
        // token3 - 100 borrows, 80 balance
        // collateral = 25 * 1 * 0.8 = 20
        // debt = 20 * 1 * 1.2 = 24
        // collateralRatio = 20/24 = 83%, looks dangerous
        // but pool has enough balance to repay debt, doesn't have bad debt
        token2.burn(address(d3MM), 975 ether);
        d3MM.updateReserve(address(token2));
        token3.burn(address(d3MM), 1020 ether);
        d3MM.updateReserve(address(token3));
        assertEq(d3Vault.checkBadDebt(address(d3MM)), false);

        // user1 liquidate the pool, repay 20 token3, take away 21 token2 as reward (20/0.95=21.05)
        vm.prank(user1);
        token3.approve(address(d3Vault), 20 ether);
        vm.prank(user1);
        d3Vault.liquidate(address(d3MM), address(token2), 21 ether, address(token3), 20 ether);
    }

    function testCannotBeLiquidated() public {
        contextCannotBeLiquidated();
        vm.prank(user2);
        vm.expectRevert(bytes(Errors.CANNOT_BE_LIQUIDATED));
        d3Vault.liquidate(address(d3MM), address(token1), 100 ether, address(token2), 100 ether);

        vm.prank(vaultOwner);
        d3Vault.addLiquidator(address(this));
        vm.expectRevert(bytes(Errors.CANNOT_BE_LIQUIDATED));
        d3Vault.startLiquidation(address(d3MM));
    }

    function testLiquidation() public {
        contextCanBeLiquidated();

        vm.prank(vaultOwner);
        d3Vault.addLiquidator(address(this));
        vm.expectRevert(bytes(Errors.NO_BAD_DEBT));
        d3Vault.startLiquidation(address(d3MM));

        // Case 1: pool has no token1 as collateral, should fail
        vm.prank(user2);
        vm.expectRevert(bytes(Errors.COLLATERAL_AMOUNT_EXCEED));
        d3Vault.liquidate(address(d3MM), address(token1), 100 ether, address(token2), 100 ether);

        // Case 2: token2 cannot be collateral, should fail
        vm.prank(user2);
        vm.expectRevert(bytes(Errors.INVALID_COLLATERAL_TOKEN));
        d3Vault.liquidate(address(d3MM), address(token2), 100 ether, address(token3), 100 ether);

        // Case 3: token3 cannot be debt, should fail
        vm.prank(user2);
        vm.expectRevert(bytes(Errors.INVALID_DEBT_TOKEN));
        d3Vault.liquidate(address(d3MM), address(token3), 100 ether, address(token3), 100 ether);

        // Case 4: the collateral amount passed in is larger than token3 balance in pool, should fail
        vm.prank(user2);
        vm.expectRevert(bytes(Errors.COLLATERAL_AMOUNT_EXCEED));
        d3Vault.liquidate(address(d3MM), address(token3), 200 ether, address(token2), 100 ether);

        // Case 5: the debt to cover amount is larger than debt, should fail
        vm.prank(user2);
        vm.expectRevert(bytes(Errors.DEBT_TO_COVER_EXCEED));
        d3Vault.liquidate(address(d3MM), address(token3), 10 ether, address(token2), 100 ether);

        // Case 6: In this case, user2 try to use 1 token2 to get 20 token3, with the price discount,
        // the most token3 he can get is 1 * 12 / (1 * 0.95) = 12.63, should fail
        token2.mint(user2, 10 ether);
        vm.prank(user2);
        token2.approve(address(d3Vault), 10 ether);
        
        vm.prank(address(d3MM));
        token3.approve(address(d3Vault), type(uint256).max);
        
        vm.prank(user2);
        vm.expectRevert(bytes(Errors.COLLATERAL_AMOUNT_EXCEED));
        d3Vault.liquidate(address(d3MM), address(token3), 20 ether, address(token2), 1 ether);

        // Case 7: User2 try to use 2 token2 to get 25 token3, with the price discount,
        // the most token3 he can get is 2 * 12 / (1 * 0.95) = 25.26, should success

        uint256 token2TotalBorrowed = d3Vault.getTotalBorrows(address(token2));
        assertEq(token2TotalBorrowed, 10 ether);
        uint256 token2CashBefore = d3Vault.getCash(address(token2));
        vm.prank(user2);
        d3Vault.liquidate(address(d3MM), address(token3), 25 ether, address(token2), 2 ether);

        // now pool has
        // balance: 4 token2, 75 token3
        // borrowed: 8 token2
        // net: -4 token2, +75 token3
        // collateralRatio = (75 * 1 * 90%) / (4 * 12 * 110%) = 127.8%
        (uint256 balance2, uint256 borrowed2) = d3Vault.getBalanceAndBorrows(address(d3MM), address(token2));
        (uint256 balance3, uint256 borrowed3) = d3Vault.getBalanceAndBorrows(address(d3MM), address(token3));
        token2TotalBorrowed = d3Vault.getTotalBorrows(address(token2));
        uint256 token2CashAfter = d3Vault.getCash(address(token2));
        assertEq(balance2, 4 ether);
        assertEq(borrowed2, 8 ether);
        assertEq(balance3, 75 ether);
        assertEq(borrowed3, 0 ether);
        assertEq(token2TotalBorrowed, 8 ether);
        assertEq(token2CashAfter - token2CashBefore, 2 ether);
        logCollateralRatio(address(d3MM));
    }

    function testStartLiquidation() public {
        contextBadDebt();

        vm.prank(user2);
        vm.expectRevert(bytes(Errors.HAS_BAD_DEBT));
        d3Vault.liquidate(address(d3MM), address(token1), 100 ether, address(token2), 100 ether);

        vm.expectRevert(bytes(Errors.NOT_ALLOWED_LIQUIDATOR));
        d3Vault.startLiquidation(address(d3MM));

        vm.prank(vaultOwner);
        d3Vault.addLiquidator(address(this));
        d3Vault.startLiquidation(address(d3MM));

        vm.expectRevert(bytes(Errors.ALREADY_IN_LIQUIDATION));
        d3Vault.startLiquidation(address(d3MM));

        // When pool is in liquidation, cannot repay
        vm.startPrank(address(d3MM));
        token1.approve(address(d3Vault), type(uint256).max);
        vm.expectRevert(bytes(Errors.ALREADY_IN_LIQUIDATION));
        d3Vault.poolRepay(address(token1), 100 * 1e8);
        vm.expectRevert(bytes(Errors.ALREADY_IN_LIQUIDATION));
        d3Vault.poolRepayAll(address(token1));
        vm.stopPrank();
    }

    function testLiquidateByDODO() public {
        contextBadDebt();
        vm.prank(vaultOwner);
        d3Vault.addLiquidator(liquidator);

        vm.expectRevert(bytes(Errors.NOT_IN_LIQUIDATION));
        liquidateSwap(address(d3MM), address(token3), address(token2), 12 ether);

        vm.prank(liquidator);
        d3Vault.startLiquidation(address(d3MM));

        // now pool has
        // balance: 5 token2, 50 token3
        // borrowed: 10 token2
        // positive net: 50 token3
        // negative net: 5 token2
        // collateralRatio = 50 * 1 * 0.9 / (5 * 12 * 1.1) = 68% < 100%
        logCollateralRatio(address(d3MM));
        
        vm.prank(address(d3MM));
        token3.approve(address(d3Vault), type(uint256).max);

        router.setSlippage(90);
        vm.expectRevert(bytes(Errors.EXCEED_DISCOUNT));
        liquidateSwap(address(d3MM), address(token3), address(token2), 12 ether);

        router.setSlippage(100);
        // using 12 token3 to swap 1 token2
        liquidateSwap(address(d3MM), address(token3), address(token2), 12 ether);
        // now pool should have 6 token2, 38 token3
        assertEq(token2.balanceOf(address(d3MM)), 6 ether);
        assertEq(token3.balanceOf(address(d3MM)), 38 ether);
    }

    function testLiquidateByDODORouteFail() public {
        contextBadDebt();
        vm.prank(vaultOwner);
        d3Vault.addLiquidator(liquidator);
        vm.prank(liquidator);
        d3Vault.startLiquidation(address(d3MM));

        
        vm.prank(address(d3MM));
        token3.approve(address(d3Vault), type(uint256).max);

        router.disableRouter();
        vm.expectRevert(bytes("router not available"));
        liquidateSwap(address(d3MM), address(token3), address(token2), 12 ether);
    }

    function testLiquidateByDODONotWhitelistedRouter() public {
        contextBadDebt();
        vm.prank(vaultOwner);
        d3Vault.addLiquidator(liquidator);
        vm.prank(liquidator);
        d3Vault.startLiquidation(address(d3MM));

        
        vm.prank(address(d3MM));
        token3.approve(address(d3Vault), type(uint256).max);

        vm.prank(vaultOwner);
        d3Vault.removeRouter(address(liquidationRouter));

        vm.expectRevert(bytes(Errors.NOT_ALLOWED_ROUTER));
        liquidateSwap(address(d3MM), address(token3), address(token2), 12 ether);
    }

    function testFinishLiquidation() public {
        vm.prank(vaultOwner);
        d3Vault.addLiquidator(liquidator);

        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.NOT_IN_LIQUIDATION));
        d3Vault.finishLiquidation(address(d3MM));

        // pool has
        // balance: 5 token2, 50 token3
        // borrowed: 10 token2
        // positive net: 50 token3
        // negative net: 5 token2
        contextBadDebt();
        
        vm.prank(liquidator);
        d3Vault.startLiquidation(address(d3MM));

        vm.prank(address(d3MM));
        token3.approve(address(d3Vault), type(uint256).max);
        vm.prank(address(d3MM));
        token2.approve(address(d3Vault), type(uint256).max);

        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.LIQUIDATION_NOT_DONE));
        d3Vault.finishLiquidation(address(d3MM));

        uint256 token2CashBefore = d3Vault.getCash(address(token2));
        liquidateSwap(address(d3MM), address(token3), address(token2), 50 ether);
        vm.prank(liquidator);
        d3Vault.finishLiquidation(address(d3MM));
        assertEq(d3MM.isInLiquidation(), false);
        uint256 token2CashAfter = d3Vault.getCash(address(token2));
        assertGt(token2CashAfter, token2CashBefore);
    }

    function testFinishLiquidationDifferenceLessThan0() public {
        vm.prank(vaultOwner);
        d3Vault.addLiquidator(liquidator);

        // pool has
        // balance: 5 token2, 50 token3
        // borrowed: 10 token2
        // positive net: 50 token3
        // negative net: 5 token2
        contextBadDebt();
        
        vm.prank(liquidator);
        d3Vault.startLiquidation(address(d3MM));

        vm.prank(address(d3MM));
        token3.approve(address(d3Vault), type(uint256).max);
        vm.prank(address(d3MM));
        token2.approve(address(d3Vault), type(uint256).max);

        router.setSlippage(96);
        liquidateSwap(address(d3MM), address(token3), address(token2), 50 ether);
        vm.prank(liquidator);
        d3Vault.finishLiquidation(address(d3MM));
        assertEq(d3MM.isInLiquidation(), false);
    }

    function testFinishLiquidationDifferenceLessThan0LiquidationNotDone() public {
        vm.prank(vaultOwner);
        d3Vault.addLiquidator(liquidator);

        // pool has
        // balance: 1 token1, 5 token2, 50 token3
        // borrowed: 10 token2
        // positive net: 1 token1, 50 token3
        // negative net: 5 token2
        contextBadDebt();
        token1.mint(address(d3MM), 1);
        
        vm.prank(liquidator);
        d3Vault.startLiquidation(address(d3MM));

        vm.prank(address(d3MM));
        token3.approve(address(d3Vault), type(uint256).max);
        vm.prank(address(d3MM));
        token2.approve(address(d3Vault), type(uint256).max);

        router.setSlippage(96);
        liquidateSwap(address(d3MM), address(token3), address(token2), 50 ether);
        vm.prank(liquidator);
        vm.expectRevert(bytes(Errors.LIQUIDATION_NOT_DONE));
        d3Vault.finishLiquidation(address(d3MM));
    }
}
