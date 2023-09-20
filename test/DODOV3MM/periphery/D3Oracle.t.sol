/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";

contract D3OracleTest is TestContext {
    error SequencerDown();
    error GracePeriodNotOver();

    function setUp() public {
        contextBasic();
    }

    function testSetSequencer() public {
        assertEq(oracle.sequencerFeed(), address(0));
        oracle.setSequencer(address(sequencerUptimeFeed));
        assertEq(oracle.sequencerFeed(), address(sequencerUptimeFeed));
    }

    function testGetPrice() public {
        assertEq(oracle.getPrice(address(token1)), 1300e28);
        assertEq(oracle.getPrice(address(token2)), 12e18);

        token2ChainLinkOracle.feedData(13 * 1e18);
        assertEq(oracle.getPrice(address(token2)), 13e18);

        // price decimals 10, token decimals 8
        oracle.setPriceSource(address(token1), PriceSource(address(token1ChainLinkOracle), true, 5e17, 10, 8, 3600));
        token1ChainLinkOracle.feedData(1300 * 1e10);
        assertEq(oracle.getPrice(address(token1)), 1300e28);
    }

    function testGetDec18PricePrice() public {
        assertEq(oracle.getDec18Price(address(token1)), 1300e18);
        assertEq(oracle.getDec18Price(address(token2)), 12e18);

        // price decimals 10, token decimals 8
        oracle.setPriceSource(address(token1), PriceSource(address(token1ChainLinkOracle), true, 5e17, 10, 8, 3600));
        token1ChainLinkOracle.feedData(1300 * 1e10);
        assertEq(oracle.getDec18Price(address(token1)), 1300e18);
    }

    function testGetOriginalPrice() public {
        (uint256 price1, ) = oracle.getOriginalPrice(address(token1));
        (uint256 price2, ) = oracle.getOriginalPrice(address(token2));
        assertEq(price1, 1300e18);
        assertEq(price2, 12e18);

        // price decimals 10, token decimals 8
        oracle.setPriceSource(address(token1), PriceSource(address(token1ChainLinkOracle), true, 5e17, 10, 8, 3600));
        token1ChainLinkOracle.feedData(1300 * 1e10);
        (uint256 price, uint8 decimals) = oracle.getOriginalPrice(address(token1));
        assertEq(price, 1300e10);
        assertEq(decimals, 10);
    }

    function testCheckSequencerActive() public {
        assertEq(oracle.getPrice(address(token1)), 1300e28);
        oracle.setSequencer(address(sequencerUptimeFeed)); 
        
        vm.expectRevert(GracePeriodNotOver.selector);
        assertEq(oracle.getPrice(address(token1)), 0);
        
        // GRACE_PERIOD_TIME not passed
        vm.warp(1 + 3600);
        vm.expectRevert(GracePeriodNotOver.selector);
        assertEq(oracle.getPrice(address(token1)), 0);
        
        // GRACE_PERIOD_TIME passed
        vm.warp(1 + 3602);
        assertEq(oracle.getPrice(address(token1)), 1300e28);

        // sequencer is down
        sequencerUptimeFeed.feedData(1);
        vm.expectRevert(SequencerDown.selector);
        assertEq(oracle.getPrice(address(token1)), 0);

        // sequencer is up
        sequencerUptimeFeed.feedData(0);
        assertEq(oracle.getPrice(address(token1)), 1300e28);

        // set sequencer to address(0) will always pass checkSequencerActive() 
        oracle.setSequencer(address(0));
        assertEq(oracle.getPrice(address(token1)), 1300e28);
    }

    function testTokenNotWhitelisted() public {
        oracle.setPriceSource(
            address(token1), 
            PriceSource(address(token1ChainLinkOracle), false, 5 * (10 ** 17), 18, 8, 3600)
        );
        vm.expectRevert(bytes("INVALID_TOKEN"));
        assertEq(oracle.getPrice(address(token1)), 0);
    }

    function testIncorrectPrice() public {
        token1ChainLinkOracle.feedData(0);
        vm.expectRevert(bytes("Chainlink: Incorrect Price"));
        assertEq(oracle.getPrice(address(token1)), 0); 
    }
}
