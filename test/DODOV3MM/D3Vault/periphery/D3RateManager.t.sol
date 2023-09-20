/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.16;

import "../../../TestContext.t.sol";
import {D3RateManager} from "D3Vault/periphery/D3RateManager.sol";

contract D3RateManagerTest is TestContext {
    D3RateManager public d3RateManager;
    function setUp() public {
        createD3UserQuotaTokens();
        d3RateManager = new D3RateManager();
    }

    function testSetStableCurve() public {
        // base 0
        // slope1 8%
        // slope2 100%
        // optimal 80%
        d3RateManager.setStableCurve(address(weth), 0, 8 * 1e16, 1 * 1e18, 80 * 1e16);
        assertEq(d3RateManager.tokenTypeMap(address(weth)),1);
        assertEq(d3RateManager.getBorrowRate(address(weth),0),0);
        // rate = 0 + 70% * 8% = 5.6%
        assertEq(d3RateManager.getBorrowRate(address(weth),70 * 1e16), 56 *1e15);

    }
    function testSetVolatileCurve() public {
        // base 0
        // slope1 8%
        // slope2 100%
        // optimal 80%
        d3RateManager.setVolatileCurve(address(weth), 0, 8 * 1e16, 1 * 1e18, 80 * 1e16);
        assertEq(d3RateManager.tokenTypeMap(address(weth)),2);
        assertEq(d3RateManager.getBorrowRate(address(weth),0),0);
        // rate = 0 + 70% * 8% = 5.6%
        assertEq(d3RateManager.getBorrowRate(address(weth),70 * 1e16), 56 *1e15);
    }
    function testSetTokenType() public {
        d3RateManager.setVolatileCurve(address(weth), 0, 8 * 1e16, 1 * 1e18, 80 * 1e16);
        assertEq(d3RateManager.tokenTypeMap(address(weth)),2);
        d3RateManager.setTokenType(address(weth),1);
        assertEq(d3RateManager.tokenTypeMap(address(weth)),1);
    }

    function testgetBorrowRate() public {
        d3RateManager.setStableCurve(address(weth), 0, 8 * 1e16, 1 * 1e18, 80 * 1e16);

        assertEq(d3RateManager.getBorrowRate(address(weth),0),0);
        // rate = 0 + 70% * 8% = 5.6%
        assertEq(d3RateManager.getBorrowRate(address(weth),70 * 1e16), 56 *1e15);
        assertEq(d3RateManager.getBorrowRate(address(weth),90 * 1e16), 164 *1e15);
    }
}