/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";

// This test is a POC of issue mentioned here:
// https://github.com/sherlock-audit/2023-06-dodo-judging/issues/248
contract PrecisionTest is TestContext {
    D3UserQuota public d3UserQutoa;

    MockERC20 public wbtc;
    address public wbtcAddr;
    address public dodoAddr;

    function setUp() public {
        contextBasic();

        wbtc = token1;
        dodo = token3;
        wbtcAddr = address(token1);
        dodoAddr = address(token3);

        wbtc.mint(user1, 1000e8);
        vm.prank(user1);
        wbtc.approve(address(dodoApprove), type(uint256).max);

        wbtc.mint(poolCreator, 1000e8);
        vm.prank(poolCreator);
        wbtc.approve(address(dodoApprove), type(uint256).max);

        dodo.mint(poolCreator, 1000000 ether);
        vm.prank(poolCreator);
        dodo.approve(address(dodoApprove), type(uint256).max);

        d3UserQutoa = new D3UserQuota(address(token4), address(d3Vault));
        vm.prank(vaultOwner);
        d3Vault.setNewD3UserQuota(address(d3UserQutoa));

        vm.prank(vaultOwner);
        d3Vault.addLiquidator(address(this));
        vm.prank(vaultOwner);
        d3Vault.addLiquidator(liquidator);
    }

    function testPOC() public {
        vm.prank(user1);
        d3Proxy.userDeposit(user1, wbtcAddr, 100e8, 90e8);

        // make dodo price high, so that pool can borrow wbtc
        token3ChainLinkOracle.feedData(1e9 * 1e18);
           
        // pool1 deposit high price dodo, and borrow wbtc
        vm.prank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), dodoAddr, 1000 ether);
        vm.prank(poolCreator);
        d3MM.borrow(wbtcAddr, 10e8);
      
        // make dodo price low
        token3ChainLinkOracle.feedData(1 * 1e18);

        vm.warp(3600 * 2);
        d3Vault.accrueInterests(); // Key step. The test will pass if the line is commented out.

        vm.warp(3600 * 3);

        // burn some wbtc, so that pool can be liquidated
        wbtc.burn(address(d3MM), 9e8);
        d3MM.updateReserve(wbtcAddr);

        d3Vault.accrueInterests();
        uint256 totalBorrows = d3Vault.getTotalBorrows(wbtcAddr);
        uint256 poolBorrows = d3Vault.getPoolBorrowAmount(address(d3MM), wbtcAddr);
        assertEq(totalBorrows, 1000102735);
        assertEq(poolBorrows, 1000102736);
        
        d3Vault.startLiquidation(address(d3MM));
        liquidateSwap(address(d3MM), dodoAddr, wbtcAddr, 1000 ether);
        d3Vault.finishLiquidation(address(d3MM));
    }

    function testPOC2() public {
        vm.prank(user1);
        d3Proxy.userDeposit(user1, wbtcAddr, 100e8, 90e8);

        // make dodo price high
        token3ChainLinkOracle.feedData(1e9 * 1e18);
           
        // pool1 deposit high price dodo, and borrow wbtc
        vm.prank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), dodoAddr, 1000 ether);
        vm.prank(poolCreator);
        d3MM.borrow(wbtcAddr, 10e8);

        uint256 i = 1;
        while (i < 365) {
            vm.warp(3600 * i);
            d3Vault.accrueInterest(wbtcAddr);
            i++;
        }

        uint256 totalBorrows = d3Vault.getTotalBorrows(wbtcAddr);
        uint256 poolBorrows = d3Vault.getPoolBorrowAmount(address(d3MM), wbtcAddr);
        assertEq(totalBorrows, 1012567753);
        assertEq(poolBorrows, 1012567938);

        vm.prank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), wbtcAddr, 1e8);
        vm.prank(poolCreator);
        d3MM.repayAll(wbtcAddr);
    }
}
