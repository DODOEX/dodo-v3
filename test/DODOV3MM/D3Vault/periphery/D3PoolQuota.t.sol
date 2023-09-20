/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.16;

import "../../../TestContext.t.sol";
import {D3PoolQuota} from "D3Vault/periphery/D3PoolQuota.sol";

contract D3PoolQuotaTest is TestContext {
    D3PoolQuota public d3PoolQuota;

    function setUp() public {
        createD3UserQuotaTokens();
        d3PoolQuota = new D3PoolQuota();
    }

    

    function testEnableQuota() public {
        d3PoolQuota.enableQuota(address(weth),false);
        assertEq(d3PoolQuota.getPoolQuota(testPool,address(weth)),type(uint256).max);

    }
    
    function testEnableDefaultQuota() public {
        d3PoolQuota.enableQuota(address(weth),true);
        d3PoolQuota.enableDefaultQuota(address(weth),true);
        assertEq(d3PoolQuota.getPoolQuota(testPool,address(weth)),0);

    }

    function testSetDefaultQuota() public {
        d3PoolQuota.enableQuota(address(weth),true);
        d3PoolQuota.enableDefaultQuota(address(weth),true);
        d3PoolQuota.setDefaultQuota(address(weth),10 * 1e18);
        assertEq(d3PoolQuota.getPoolQuota(testPool,address(weth)),10 * 1e18);
    }

    function testSetPoolQuota() public{
        d3PoolQuota.enableQuota(address(weth),true);
        d3PoolQuota.enableDefaultQuota(address(weth),false);
        address[] memory pools = new address[](1);
        pools[0] = testPool;
        uint256[] memory quotas = new uint256[](1);
        quotas[0] = 10 * 1e18;
        d3PoolQuota.setPoolQuota(address(weth),pools,quotas);
        assertEq(d3PoolQuota.getPoolQuota(testPool,address(weth)),10 * 1e18);
    }
}
