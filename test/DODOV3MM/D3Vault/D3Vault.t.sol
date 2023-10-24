/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";

contract D3VaultTest is TestContext {
    function setUp() public {
        contextBasic();
    }

    function testInit() public {
        assertEq(d3Vault.owner(), vaultOwner);
    }

    function testAddAndRemoveD3Pool() public {
        // remove a pool never added before
        vm.prank(vaultOwner);
        vm.expectRevert(bytes(Errors.POOL_NOT_ADDED));
        d3Vault.removeD3Pool(address(1234));

        address pool = d3MMFactory.breedD3Pool(address(1234), address(1234), 100000, 0);
        assertEq(d3Vault.allPoolAddrMap(pool), true);
        assertEq(d3Vault.creatorPoolMap(address(1234), 0), pool);

        // D3MMFactory add an already added pool
        vm.expectRevert(bytes(Errors.POOL_ALREADY_ADDED));
        d3MMFactory.addD3Pool(pool);

        vm.prank(vaultOwner);
        d3Vault.removeD3Pool(pool);
        assertEq(d3Vault.allPoolAddrMap(pool), false);

        vm.prank(vaultOwner);
        d3Vault.addD3Pool(pool);
        assertEq(d3Vault.allPoolAddrMap(pool), true);

        // add a pool which has already been added
        vm.prank(vaultOwner);
        vm.expectRevert(bytes(Errors.POOL_ALREADY_ADDED));
        d3Vault.addD3Pool(pool);

        address pool2 = d3MMFactory.breedD3Pool(address(1234), address(1234), 100000, 0);
        vm.prank(vaultOwner);
        vm.expectRevert(bytes(Errors.HAS_POOL_PENDING_REMOVE));
        d3Vault.removeD3Pool(pool2);

        vm.startPrank(vaultOwner);
        d3Vault.finishPoolRemove();
        d3Vault.removeD3Pool(pool2);
        d3Vault.finishPoolRemove();
        assertEq(d3Vault.allPoolAddrMap(pool2), false);
        vm.stopPrank();

        address pool3 = d3MMFactory.breedD3Pool(address(1234), address(1234), 100000, 0);
        assertEq(d3Vault.creatorPoolMap(address(1234), 1), pool3);

        address pool4 = d3MMFactory.breedD3Pool(address(1234), address(1234), 100000, 0);
        assertEq(d3Vault.creatorPoolMap(address(1234), 2), pool4);
        
        vm.startPrank(vaultOwner);
        d3Vault.removeD3Pool(pool3);
        d3Vault.finishPoolRemove();
        assertEq(d3Vault.creatorPoolMap(address(1234), 1), pool4);

        assertEq(d3Vault.creatorPoolMap(address(1234), 0), pool);
        d3Vault.removeD3Pool(pool);
        d3Vault.finishPoolRemove();
        assertEq(d3Vault.creatorPoolMap(address(1234), 0), pool4);
        vm.stopPrank();
    }

    function testRemovePoolHasBorrow() public {
        token1.mint(user1, type(uint256).max);
        vm.prank(user1);
        token1.approve(address(dodoApprove), type(uint256).max);

        mockUserQuota.setUserQuota(user1, address(token1), 1000 * 1e8);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token1), 500 * 1e8, 0);

        token1.mint(address(d3MM), 100 * 1e8);
        d3MM.makerDeposit(address(token1));
        vm.prank(poolCreator);
        d3MM.borrow(address(token1), 50 * 1e8);

        vm.startPrank(vaultOwner);
        d3Vault.removeD3Pool(address(d3MM));
        assertEq(d3Vault._PENDING_REMOVE_POOL_(), address(d3MM));
        assertEq(token1.balanceOf(address(d3MM)), 150 * 1e8);
        
        d3Vault.pendingRemovePoolRepayAll(address(token1));
        assertEq(token1.balanceOf(address(d3MM)), 100 * 1e8);
        vm.stopPrank();

        // pool is in "liquidation" state when pending remove
        vm.prank(user2);
        vm.expectRevert(bytes(Errors.ALREADY_IN_LIQUIDATION));
        d3Vault.liquidate(address(d3MM), address(token1), 100 ether, address(token2), 100 ether);
        
        vm.prank(vaultOwner);
        d3Vault.finishPoolRemove();
        assertEq(d3Vault._PENDING_REMOVE_POOL_(), address(0));
        
    }

    function testSetCloneFactory() public {
        vm.prank(vaultOwner);
        d3Vault.setCloneFactory(address(123));
        assertEq(d3Vault._CLONE_FACTORY_(), address(123));
    }

    function testSetNewD3Factory() public {
        vm.prank(vaultOwner);
        d3Vault.setNewD3Factory(address(123));
        assertEq(d3Vault._D3_FACTORY_(), address(123));
    }

    function testSetNewD3UserQuota() public {
        vm.prank(vaultOwner);
        d3Vault.setNewD3UserQuota(address(123));
        assertEq(d3Vault._USER_QUOTA_(), address(123));
    }

    function testSetNewD3PoolQuota() public {
        vm.prank(vaultOwner);
        d3Vault.setNewD3PoolQuota(address(123));
        assertEq(d3Vault._POOL_QUOTA_(), address(123));
    }

    function testSetNewOracle() public {
        vm.prank(vaultOwner);
        d3Vault.setNewOracle(address(123));
        assertEq(d3Vault._ORACLE_(), address(123));
    }

    function testSetNewRateManager() public {
        vm.prank(vaultOwner);
        d3Vault.setNewRateManager(address(123));
        assertEq(d3Vault._RATE_MANAGER_(), address(123));
    }

    function testSetMaintainer() public {
        vm.prank(vaultOwner);
        d3Vault.setMaintainer(address(123));
        assertEq(d3Vault._MAINTAINER_(), address(123));
    }

    function testSetIM() public {
        vm.prank(vaultOwner);
        d3Vault.setIM(123);
        assertEq(d3Vault.IM(), 123);
    }

    function testSetMM() public {
        vm.prank(vaultOwner);
        d3Vault.setMM(123);
        assertEq(d3Vault.MM(), 123);
    }

    function testSetDiscount() public {
        vm.prank(vaultOwner);
        d3Vault.setDiscount(123);
        assertEq(d3Vault.DISCOUNT(), 123);
    }

    function testSetDTokenTemplate() public {
        vm.prank(vaultOwner);
        d3Vault.setDTokenTemplate(address(123));
        assertEq(d3Vault._D3TOKEN_LOGIC_(), address(123));
    }

    function testAddAndRemoveRouter() public {
        vm.prank(vaultOwner);
        d3Vault.addRouter(address(123));
        assertEq(d3Vault.allowedRouter(address(123)), true);

        vm.prank(vaultOwner);
        d3Vault.removeRouter(address(123));
        assertEq(d3Vault.allowedRouter(address(123)), false);
    }

    function testAddAndRemoveLiquidator() public {
        vm.prank(vaultOwner);
        d3Vault.addLiquidator(address(123));
        assertEq(d3Vault.allowedLiquidator(address(123)), true);

        vm.prank(vaultOwner);
        d3Vault.removeLiquidator(address(123));
        assertEq(d3Vault.allowedLiquidator(address(123)), false);
    }

    function testAddNewToken() public {
        vm.startPrank(vaultOwner);
        vm.expectRevert(bytes(Errors.TOKEN_ALREADY_EXIST));
        d3Vault.addNewToken(address(token1), 0, 0, 0, 0, 0);
        vm.expectRevert(bytes(Errors.WRONG_WEIGHT));
        d3Vault.addNewToken(address(token4), 0, 0, 0, 0, 0);
        vm.expectRevert(bytes(Errors.WRONG_RESERVE_FACTOR));
        d3Vault.addNewToken(address(token4), 0, 0, 80e16, 120e16, 2e18);
        d3Vault.addNewToken(address(token4), 0, 0, 80e16, 120e16, 20e16);
        vm.stopPrank();
    }

    function testSetToken() public {
        vm.startPrank(vaultOwner);
        vm.expectRevert(bytes(Errors.TOKEN_NOT_EXIST));
        d3Vault.setToken(address(token4), 0, 0, 0, 0, 0);
        vm.expectRevert(bytes(Errors.WRONG_WEIGHT));
        d3Vault.setToken(address(token1), 0, 0, 0, 0, 0);
        vm.expectRevert(bytes(Errors.WRONG_RESERVE_FACTOR));
        d3Vault.setToken(address(token1), 0, 0, 80e16, 120e16, 2e18);
        d3Vault.setToken(address(token1), 0, 0, 80e16, 120e16, 20e16);
        vm.stopPrank(); 
    }

    function testGetIMMM() public {
        (uint256 IM, uint256 MM) = d3Vault.getIMMM();
        assertEq(IM, 40e16);
        assertEq(MM, 20e16);
    }

    function testGetTokenList() public {
        address[] memory list = d3Vault.getTokenList();
        assertEq(list[0], address(token1));
    }

    function testGetTotalDebtValue() public {
        vm.prank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);
        vm.prank(user1);
        token3.approve(address(dodoApprove), type(uint256).max);

        token2.mint(user1, 1000 ether);
        token3.mint(user1, 1000 ether);
        mockUserQuota.setUserQuota(user1, address(token2), 1000 ether);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);
        mockUserQuota.setUserQuota(user1, address(token3), 1000 ether);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token3), 500 ether, 0);

        token2.mint(address(d3MM), 100 ether);
        poolBorrow(address(d3MM), address(token2), 100 ether);
        token3.mint(address(d3MM), 100 ether);
        poolBorrow(address(d3MM), address(token3), 100 ether);

        // pool borrows 100 token2, 100 token3
        // token2 price 1
        // token3 price 12
        // totalDebt = 100 * 1 + 100 * 12 = 1300
        assertEq(d3Vault.getTotalDebtValue(address(d3MM)), 1300 ether);
    }

    function testWithdrawReserves() public {
        vm.prank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);

        // deposit 500 token2
        token2.mint(user1, 1000 ether);
        mockUserQuota.setUserQuota(user1, address(token2), 1000 ether);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);
        logAssetInfo(address(token2));

        // borrow 100 token2
        token2.mint(address(d3MM), 100 ether);
        poolBorrow(address(d3MM), address(token2), 100 ether);
        logAssetInfo(address(token2));

        vm.warp(365 days + 1);

        d3Vault.accrueInterest(address(token2));
        uint256 reserves = d3Vault.getReservesInVault(address(token2));
        logAssetInfo(address(token2));
        uint256 cashBefore = d3Vault.getCash(address(token2));
        uint256 exchangeRateBefore = d3Vault.getExchangeRate(address(token2));
        vm.prank(vaultOwner);
        d3Vault.withdrawReserves(address(token2), reserves - 100);
        uint256 cashAfter = d3Vault.getCash(address(token2));
        uint256 exchangeRateAfter = d3Vault.getExchangeRate(address(token2));
        uint256 reservesAfter = d3Vault.getReservesInVault(address(token2));
        assertEq(reservesAfter, 100);
        assertEq(cashBefore - cashAfter, reserves - 100);
        assertEq(exchangeRateBefore, exchangeRateAfter);
        assertEq(token2.balanceOf(maintainer), reserves - 100);
        logAssetInfo(address(token2));

        vm.prank(vaultOwner);
        vm.expectRevert(bytes(Errors.WITHDRAW_AMOUNT_EXCEED));
        d3Vault.withdrawReserves(address(token2), 101);

        // if _MAINTAINER_ is not set, withdrawReserves should revert
        vm.prank(vaultOwner);
        d3Vault.setMaintainer(address(0));
        vm.prank(vaultOwner);
        vm.expectRevert(bytes(Errors.MAINTAINER_NOT_SET));
        d3Vault.withdrawReserves(address(token2), 101);
    }

    function testWithdrawLeft() public {
        vm.prank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);

        token2.mint(user1, 2000 ether);
        mockUserQuota.setUserQuota(user1, address(token2), 2000 ether);

        // deposit 500 token2
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);
        logAssetInfo(address(token2));

        // attacker transfer 1000 token2 into vault
        // the max allowed deposit amount of token2 is 1000
        // now no one can deposit into vault, since it will exceed the max deposit amount
        token2.mint(user2, 1000 ether);
        vm.prank(user2);
        token2.transfer(address(d3Vault), 1000 ether);

        // userDeposit is blocked
        vm.expectRevert(bytes(Errors.EXCEED_MAX_DEPOSIT_AMOUNT));
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);

        // userDeposit is unblocked
        // uint256 balanceBefore = token2.balanceOf(maintainer);
        // vm.prank(vaultOwner);
        // d3Vault.withdrawLeft(address(token2));
        // uint256 balanceAfter = token2.balanceOf(maintainer);
        // assertEq(balanceAfter - balanceBefore, 1000 ether);
        // vm.prank(user1);
        // d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);

        // if _MAINTAINER_ is not set, withdrawLeft should revert
        // vm.prank(vaultOwner);
        // d3Vault.setMaintainer(address(0));
        // vm.prank(vaultOwner);
        // vm.expectRevert(bytes(Errors.MAINTAINER_NOT_SET));
        // d3Vault.withdrawLeft(address(token2));
    }

    function testGetCollateralRatio() public {
        assertEq(d3Vault.getCollateralRatio(address(d3MM)), 1e18);

        token1.mint(address(d3MM), 100);
        vm.prank(poolCreator);
        d3MM.makerDeposit(address(token1));
        assertEq(d3Vault.getCollateralRatio(address(d3MM)), type(uint256).max);
    }

    function testGetCumulativeBorrowRate() public {
        vm.prank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);

        // deposit 500 token2
        token2.mint(user1, 1000 ether);
        mockUserQuota.setUserQuota(user1, address(token2), 1000 ether);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);
        logAssetInfo(address(token2));

        // borrow 100 token2
        token2.mint(address(d3MM), 100 ether);
        poolBorrow(address(d3MM), address(token2), 100 ether);
        logAssetInfo(address(token2));

        vm.warp(365 days + 1);

        //d3Vault.accrueInterest(address(token2));
        (uint256 rate, ) = d3Vault.getCumulativeBorrowRate(address(d3MM), address(token2));
        assertEq(rate, 1479561541141168000);
    }
}
