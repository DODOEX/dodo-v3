/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.16;

import "../../TestContext.t.sol";

contract D3MMFactoryTest is TestContext {
    function setUp() public {
        contextBasic();
    }

    function testSetD3Temp() public {
        D3MM d3MMTempNew = new D3MM();
        d3MMFactory.setD3Temp(0, address(d3MMTempNew));
        assertEq(d3MMFactory._D3POOL_TEMPS(0), address(d3MMTempNew));
    }

    function testSetD3MakerTemp() public {
        D3Maker d3MakerTempNew = new D3Maker();
        d3MMFactory.setD3MakerTemp(0, address(d3MakerTempNew));
        assertEq(d3MMFactory._D3MAKER_TEMPS_(0), address(d3MakerTempNew));
    }

    function testSetCloneFactory() public {
        CloneFactory cloneFactoryNew = new CloneFactory();
        d3MMFactory.setCloneFactory(address(cloneFactoryNew));
        assertEq(d3MMFactory._CLONE_FACTORY_(), address(cloneFactoryNew));
    }

    function testSetOracle() public {
        createD3Oracle();
        d3MMFactory.setOracle(address(oracle));
        assertEq(d3MMFactory._ORACLE_(), address(oracle));
    }

    function testSetMaintainer() public {
        // vm.prank(owner);
        d3MMFactory.setMaintainer(user1);
        assertEq(d3MMFactory._MAINTAINER_(), user1);
    }

    function testSetFeeRate() public {
        createMockOracle();
        // vm.prank(owner);
        d3MMFactory.setFeeRate(user1);
        assertEq(d3MMFactory._FEE_RATE_MODEL_(), user1);
    }

    function testBreedD3Pool() public {
        address pool = d3MMFactory.breedD3Pool(user1, user2, 100000, 0);
        assertEq(d3Vault.allPoolAddrMap(pool), true);
    }
}
