/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.16;

import "../../../TestContext.t.sol";
import {D3Token} from "D3Vault/periphery/D3Token.sol";

contract D3TokenTest is TestContext {
    D3Token public d3Token;

    function setUp() public {
        createD3UserQuotaTokens();
        d3Token = new D3Token();
        d3Token.init(address(weth),testPool);
    }

    function testMint() public {
        vm.startPrank(testPool);
        d3Token.mint(user1,100 * 1e18);
        vm.stopPrank();
        assertEq(d3Token.balanceOf(user1),100 * 1e18);
    }

    function testBurn() public {
        vm.startPrank(testPool);
        d3Token.mint(user1,100 * 1e18);
        d3Token.burn(user1,50 * 1e18);
        vm.stopPrank();
        assertEq(d3Token.balanceOf(user1),50 * 1e18);
    }

    function testTransfer() public {
        vm.prank(testPool);
        d3Token.mint(user1,100 * 1e18);
        vm.prank(user1);
        d3Token.transfer(user2,50 * 1e18);
        assertEq(d3Token.balanceOf(user1),50 * 1e18);
        assertEq(d3Token.balanceOf(user2),50 * 1e18);

    }

    function testTransferFrom() public {
        vm.prank(testPool);
        d3Token.mint(user1,100 * 1e18);
        vm.prank(user1);
        d3Token.approve(user2, type(uint256).max);
        vm.prank(user2);
        d3Token.transferFrom(user1,user3,50 * 1e18);
        assertEq(d3Token.balanceOf(user1),50 * 1e18);
        assertEq(d3Token.balanceOf(user3),50 * 1e18);
    }

    function testTransferFromTwo() public {
        vm.prank(testPool);
        d3Token.mint(user1,100 * 1e18);
        vm.prank(user1);
        d3Token.approve(user2, 100 * 1e18);
        vm.prank(user2);
        d3Token.transferFrom(user1,user3,50 * 1e18);
        assertEq(d3Token.balanceOf(user1),50 * 1e18);
        assertEq(d3Token.balanceOf(user3),50 * 1e18);
        assertEq(d3Token.allowance(user1,user2),50 * 1e18);

    }

    function testAddressToShortString() public {
        string memory ad = d3Token.addressToShortString(testPool);
        // console2.log("ad = ",ad);
        assertEq(ad,"00000000");

    }

    function testAddressToShortStringTwo() public {
        string memory ad = d3Token.addressToShortString(address(99999999999999999999999999999999999999999999999));
        // console2.log("ad = ",ad);
        assertEq(ad,"118427b3");

    }

    function testSymbol() public {
        assertEq(d3Token.symbol(),"d3WETH");
    }
    function testName() public {
        string memory ad = d3Token.addressToShortString(address(testPool));
        assertEq(d3Token.name(),string.concat("d3WETH", "_", ad));
    }
    function testDecimals() public {
        assertEq(d3Token.decimals(),weth.decimals());
    }
}