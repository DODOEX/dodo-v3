/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";
//import {Errors} from "contracts/DODOV3MM/lib/Errors.sol";


contract D3FundingTest is TestContext {
    MockERC20 public tokenEx;
    MockChainlinkPriceFeed public tokenExChainLinkOracle;

    function setUp() public {
        contextBasic();
        setVaultAsset();
        mintPoolCreator();

        tokenEx = new MockERC20("TokenEx", "TKEx", 18);
        tokenExChainLinkOracle = new MockChainlinkPriceFeed("TokenEx/USD", 18);
        tokenExChainLinkOracle.feedData(24 * 1e18);
        
    }

    function testBorrowAndMakerDeposit() public {
        // check not borrow safe
        vm.prank(poolCreator);
        vm.expectRevert(bytes(PoolErrors.NOT_SAFE));
        d3MM.borrow(address(token1), 10 * 1e8);

        // not enough collateral
        vm.startPrank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), address(token1), 1e8);
        vm.expectRevert(bytes(PoolErrors.NOT_BORROW_SAFE));
        d3MM.borrow(address(token1), 100 * 1e8);
        vm.stopPrank();

        // maker deposit and borrow
        vm.startPrank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), address(token1), 100 * 1e8);
        d3MM.borrow(address(token1), 100 * 1e8);
        vm.stopPrank();

        // deposit invalid token
        uint256 beforeRatio = d3Vault.getCollateralRatio(address(d3MM));
        tokenEx.mint(address(d3MM), 100 * 1e18);
        vm.expectRevert(bytes("D3MM_TOKEN_NOT_FEASIBLE"));
        d3MM.makerDeposit(address(tokenEx));

        oracle.setPriceSource(
            address(tokenEx), PriceSource(address(tokenExChainLinkOracle), true, 5 * (10 ** 17), 18, 18, 3600)
        );
        d3MM.makerDeposit(address(tokenEx));
        uint256 afterRatio = d3Vault.getCollateralRatio(address(d3MM));
        uint256 approveAmount = tokenEx.allowance(address(d3Vault),address(d3MM));
        assertEq(approveAmount, 0);
        assertEq(afterRatio, beforeRatio);

        oracle.setTokenOracleFeasible(address(tokenEx), false);
        tokenEx.mint(address(d3MM), 100 * 1e18);
        vm.expectRevert(bytes("D3MM_TOKEN_NOT_FEASIBLE"));
        d3MM.makerDeposit(address(tokenEx));
        
    }

    function testRepay() public {
        // maker deposit and borrow
        vm.startPrank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), address(token1), 50 * 1e8);
        d3MM.borrow(address(token1), 100 * 1e8);

        d3MM.repay(address(token1), 10 * 1e8);

        vm.warp(3153000000000000000);
        vm.expectRevert();
        d3MM.repay(address(token1), 90 * 1e8);
    }

    function testRepayAll() public {
        // maker deposit and borrow
        vm.startPrank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), address(token1), 50 * 1e8);
        d3MM.borrow(address(token1), 100 * 1e8);

        // pass
        vm.warp(3153);
        d3MM.repayAll(address(token1));

        d3MM.borrow(address(token1), 100 * 1e8);
        vm.warp(3153000000000000000);
        uint256 ratio = d3Vault.getCollateralRatio(address(d3MM));
        assertEq(ratio, 0);
        vm.expectRevert();
        d3MM.repayAll(address(token1));
        vm.stopPrank();
    }

    function testCanBeLiquidated() public {
        vm.startPrank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), address(token1), 41 * 1e8);
        d3MM.borrow(address(token1), 100 * 1e8);

        // pass
        vm.warp(315300000000);
        uint256 ratio = d3Vault.getCollateralRatio(address(d3MM));
        assertEq(ratio, 0);
        bool can = d3MM.checkCanBeLiquidated();
        assertEq(can, true);
    }

    function testMakerWithdaw() public {
        vm.startPrank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), address(token1), 100 * 1e8);
        d3MM.borrow(address(token1), 100 * 1e8);
        
        // balance: 200 token1
        // borrowed: 100 token1
        // token1's max collateral amount is 100, 
        // only 100 token1 can be used as collateral
        // collateralRatio = 0 / 0 = 0 < IM
        vm.expectRevert(bytes("D3MM_NOT_SAFE"));
        d3MM.makerWithdraw(poolCreator, address(token1), 100 * 1e8);

        // balance: 200 token1
        // borrowed: 100 token1
        // token1's max collateral amount is 100, 
        // only 100 token1 can be used as collateral
        // collateralRatio = 10 / 0 = max > IM
        // collateralBorrowRatio = 10 / 100 = 10% < IM
        vm.expectRevert(bytes("D3MM_NOT_BORROW_SAFE"));
        d3MM.makerWithdraw(poolCreator, address(token1), 90 * 1e8);

        // balance: 200 token1
        // borrowed: 100 token1
        // token1's max collateral amount is 100, 
        // only 100 token1 can be used as collateral
        // collateralRatio = 10 / 0 = max > IM
        // collateralBorrowRatio = 10 / 100 = 10% < IM
        d3Proxy.makerDeposit(address(d3MM), address(token2), 100 * 1e18);
        d3MM.makerWithdraw(poolCreator, address(token1), 50* 1e8);
    }
}