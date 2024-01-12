/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";
import "mock/MockD3Pool.sol";
import {Types} from "contracts/DODOV3MM/lib/Types.sol";
import {D3Maker} from "D3Pool/D3Maker.sol";

contract MakerTest is TestContext {
    D3Maker public d3Maker;
    MockD3Pool public mockd3MM;

    function setUp() public {
        contextBasic();
        setVaultAsset();
        setPoolAsset();

        /*
        createTokens();
        mockd3MM = new MockD3Pool();
        */
        d3Maker = new D3Maker();
        d3Maker.init(owner, address(d3MM), 100000);
        vm.prank(poolCreator);
        d3MM.setNewMaker(address(d3Maker));

        uint256 allFlag = (2 ** 10) - 1;
        d3MM.setAllFlagByAnyone(allFlag);
    }

    function setAllTokenInfo() public {
        MakerTypes.TokenMMInfoWithoutCum memory token1Info = contructToken1MMInfo();
        vm.startPrank(owner);
        d3Maker.setNewToken(address(token1), true, token1Info.priceInfo, token1Info.amountInfo, token1Info.kAsk, token1Info.kBid);
        d3Maker.setNewToken(address(token2), true, token1Info.priceInfo, token1Info.amountInfo, token1Info.kAsk, token1Info.kBid); // dec is 8
        d3Maker.setNewToken(address(token3), false, token1Info.priceInfo, token1Info.amountInfo, token1Info.kAsk, token1Info.kBid);
        d3Maker.setNewToken(address(token4), false, token1Info.priceInfo, token1Info.amountInfo, token1Info.kAsk, token1Info.kBid); // dec is 8
        vm.stopPrank();

        uint256 flag = d3MM.getTokenFlag(address(token1));
        assertEq(flag, 1);
        flag = d3MM.getTokenFlag(address(token2));
        assertEq(flag, 1);
        flag = d3MM.getTokenFlag(address(token3));
        assertEq(flag, 1);
        flag = d3MM.getTokenFlag(address(token4));
        assertEq(flag, 1);
    }

    function testSetNewToken() public {
        setAllTokenInfo();
        MakerTypes.TokenMMInfoWithoutCum memory token1Info = contructToken1MMInfo();

        Types.TokenMMInfo memory tokenMMInfo;
        uint256 tokenIndex;

        // token1 check
        tokenIndex = uint256(d3Maker.getOneTokenOriginIndex(address(token1)));
        assertEq(tokenIndex, 0);
        uint256 priceInfo = d3Maker.getOneTokenPriceSet(address(token1));
        assertEq(priceInfo, token1Info.priceInfo);

        (tokenMMInfo, tokenIndex) = d3Maker.getTokenMMInfoForPool(address(token1));
        assertEq(tokenMMInfo.askUpPrice, 130156 * (10 ** 16));
        assertEq(tokenMMInfo.askDownPrice, 130078 * (10 ** 16));
        assertEq(tokenMMInfo.bidUpPrice, 770000770000771); //1298.7
        assertEq(tokenMMInfo.bidDownPrice, 769692584781639); // 1299.22
        assertEq(tokenMMInfo.askAmount, 30 * (10 ** 18));
        assertEq(tokenMMInfo.bidAmount, 30 * (10 ** 18));

        //token4 check
        tokenIndex = uint256(d3Maker.getOneTokenOriginIndex(address(token4)));
        assertEq(tokenIndex, 3);
        priceInfo = d3Maker.getOneTokenPriceSet(address(token4));
        assertEq(priceInfo, token1Info.priceInfo);

        (tokenMMInfo, tokenIndex) = d3Maker.getTokenMMInfoForPool(address(token4));
        assertEq(tokenMMInfo.askUpPrice, 130156 * (10 ** 16));
        assertEq(tokenMMInfo.askDownPrice, 130078 * (10 ** 16));
        assertEq(tokenMMInfo.bidUpPrice, 770000770000771); //1298.7
        assertEq(tokenMMInfo.bidDownPrice, 769692584781639); // 1299.22
        assertEq(tokenMMInfo.askAmount, 30 * (10 ** 18));
        assertEq(tokenMMInfo.bidAmount, 30 * (10 ** 18));

        // have set check
        vm.expectRevert(bytes("D3MAKER_HAVE_SET_TOKEN_INFO"));
        vm.prank(owner);
        d3Maker.setNewToken(
            address(token1), true, token1Info.priceInfo, token1Info.amountInfo, token1Info.kAsk, token1Info.kBid
        );

        (uint256 lastHeartBeat, uint256 maxInterval) = d3Maker.getHeartbeat();
        assertEq(lastHeartBeat, block.timestamp);
        assertEq(maxInterval, 100000);
    }

    function testCallInvalidToken() public {
        Types.TokenMMInfo memory tokenMMInfo;

        (tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token1));
        assertEq(tokenMMInfo.askAmount, 0);

        vm.expectRevert(bytes("D3MAKER_INVALID_TOKEN"));
        d3Maker.getOneTokenPriceSet(address(token1));

        int256 index = d3Maker.getOneTokenOriginIndex(address(token1));
        assertEq(index, -1);
    }

    function testSetTokenPrice() public {
        setAllTokenInfo();
        uint256 flag;

        uint80 wbtcPriceInfo = stickPrice(27880, 18, 6, 12, 10);
        // set 1 token
        {
            uint80[] memory priceInfos = new uint80[](1);
            priceInfos[0] = wbtcPriceInfo;
            address[] memory tokens = new address[](1);
            tokens[0] = address(token1);

            vm.prank(owner);
            d3Maker.setTokensPrice(tokens, priceInfos);
            // check
            (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token1));
            assertEq(tokenMMInfo.askUpPrice, 27913456 * (10 ** 15)); // 27913.456
            assertEq(tokenMMInfo.askDownPrice, 27896728 * (10 ** 15)); // 27896.728
            assertEq(tokenMMInfo.bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
            assertEq(tokenMMInfo.bidDownPrice, 35889539462559); // 1/27863.272

            flag = d3MM.getTokenFlag(address(token1));
            assertEq(flag, 0);
        }

        // set 2 token
        {
            uint80[] memory priceInfos = new uint80[](2);
            priceInfos[0] = priceInfos[1] = wbtcPriceInfo;
            address[] memory tokens = new address[](2);
            tokens[0] = address(token1);
            tokens[1] = address(token2);

            vm.prank(owner);
            d3Maker.setTokensPrice(tokens, priceInfos);
            // check
            (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token2));
            assertEq(tokenMMInfo.askUpPrice, 27913456 * (10 ** 15)); // 27913.456
            assertEq(tokenMMInfo.askDownPrice, 27896728 * (10 ** 15)); // 27896.728
            assertEq(tokenMMInfo.bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
            assertEq(tokenMMInfo.bidDownPrice, 35889539462559); // 1/27863.272

            flag = d3MM.getTokenFlag(address(token1));
            assertEq(flag, 0);
            flag = d3MM.getTokenFlag(address(token2));
            assertEq(flag, 0);
        }

        // set 3(2+1) token
        {
            uint80[] memory priceInfos = new uint80[](3);
            priceInfos[0] = priceInfos[1] = wbtcPriceInfo;
            priceInfos[2] = wbtcPriceInfo;
            address[] memory tokens = new address[](3);
            tokens[0] = address(token1);
            tokens[1] = address(token2);
            tokens[2] = address(token4);

            vm.prank(owner);
            d3Maker.setTokensPrice(tokens, priceInfos);
            // check
            (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token4));
            assertEq(tokenMMInfo.askUpPrice, 27913456 * (10 ** 15)); // 27913.456
            assertEq(tokenMMInfo.askDownPrice, 27896728 * (10 ** 15)); // 27896.728
            assertEq(tokenMMInfo.bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
            assertEq(tokenMMInfo.bidDownPrice, 35889539462559); // 1/27863.272

            flag = d3MM.getTokenFlag(address(token1));
            assertEq(flag, 0);
            flag = d3MM.getTokenFlag(address(token2));
            assertEq(flag, 0);
            flag = d3MM.getTokenFlag(address(token4));
            assertEq(flag, 0);
        }

        // token and price not match
        {
            uint80[] memory priceInfos = new uint80[](3);
            priceInfos[0] = priceInfos[1] = wbtcPriceInfo;
            priceInfos[2] = wbtcPriceInfo;
            address[] memory tokens = new address[](2);
            tokens[0] = address(token1);
            tokens[1] = address(token2);

            vm.expectRevert(bytes("D3MAKER_PRICES_LENGTH_NOT_MATCH"));
            vm.prank(owner);
            d3Maker.setTokensPrice(tokens, priceInfos);
        }
    }

    function testSetStablePriceSlot() public {
        setAllTokenInfo();
        uint256 flag;

        // set 1 token
        {
            uint80 wbtcPriceInfo = stickPrice(27880, 18, 6, 12, 10);
            (, uint256[] memory tokenPriceStable,) = d3Maker.getStableTokenInfo();
            uint256 newSlot = d3Maker.stickPrice(tokenPriceStable[0], 0, wbtcPriceInfo);

            uint256[] memory slotIndex = new uint256[](1);
            slotIndex[0] = 0;
            uint256[] memory priceSlots = new uint256[](1);
            priceSlots[0] = newSlot;
            vm.prank(owner);
            d3Maker.setStablePriceSlot(slotIndex, priceSlots, 0);

            // check
            (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token1));
            assertEq(tokenMMInfo.askUpPrice, 27913456 * (10 ** 15)); // 27913.456
            assertEq(tokenMMInfo.askDownPrice, 27896728 * (10 ** 15)); // 27896.728
            assertEq(tokenMMInfo.bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
            assertEq(tokenMMInfo.bidDownPrice, 35889539462559); // 1/27863.272

            flag = d3MM.getTokenFlag(address(token1));
            assertEq(flag, 0);
        }

        // set 2 token
        {
            uint80 wbtcPriceInfo = stickPrice(27880, 18, 6, 12, 10);
            (, uint256[] memory tokenPriceStable,) = d3Maker.getStableTokenInfo();
            uint256 newSlot = d3Maker.stickPrice(tokenPriceStable[0], 0, wbtcPriceInfo);
            newSlot = d3Maker.stickPrice(newSlot, 1, wbtcPriceInfo);

            uint256[] memory slotIndex = new uint256[](1);
            slotIndex[0] = 0;
            uint256[] memory priceSlots = new uint256[](1);
            priceSlots[0] = newSlot;
            vm.prank(owner);
            d3Maker.setStablePriceSlot(slotIndex, priceSlots, 0);

            // check
            (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token2));
            assertEq(tokenMMInfo.askUpPrice, 27913456 * (10 ** 15)); // 27913.456
            assertEq(tokenMMInfo.askDownPrice, 27896728 * (10 ** 15)); // 27896.728
            assertEq(tokenMMInfo.bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
            assertEq(tokenMMInfo.bidDownPrice, 35889539462559); // 1/27863.272

            flag = d3MM.getTokenFlag(address(token1));
            assertEq(flag, 0);
            flag = d3MM.getTokenFlag(address(token2));
            assertEq(flag, 0);
        }

        // prices and slots not match
        {
            uint256[] memory slotIndex = new uint256[](2);
            slotIndex[0] = slotIndex[1] = 0;
            uint256[] memory priceSlots = new uint256[](1);
            priceSlots[0] = 100000;

            vm.expectRevert(bytes("D3MAKER_PRICE_SLOT_LENGTH_NOT_MATCH"));
            vm.prank(owner);
            d3Maker.setNSPriceSlot(slotIndex, priceSlots, 0);
        }
    }

    function testSetNSPriceSlot() public {
        setAllTokenInfo();

        // set 1 token
        {
            uint80 wbtcPriceInfo = stickPrice(27880, 18, 6, 12, 10);
            (, uint256[] memory tokenPriceStable,) = d3Maker.getNSTokenInfo();
            uint256 newSlot = d3Maker.stickPrice(tokenPriceStable[0], 0, wbtcPriceInfo);

            uint256[] memory slotIndex = new uint256[](1);
            slotIndex[0] = 0;
            uint256[] memory priceSlots = new uint256[](1);
            priceSlots[0] = newSlot;
            vm.prank(owner);
            d3Maker.setNSPriceSlot(slotIndex, priceSlots, 0);

            // check
            (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token3));
            assertEq(tokenMMInfo.askUpPrice, 27913456 * (10 ** 15)); // 27913.456
            assertEq(tokenMMInfo.askDownPrice, 27896728 * (10 ** 15)); // 27896.728
            assertEq(tokenMMInfo.bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
            assertEq(tokenMMInfo.bidDownPrice, 35889539462559); // 1/27863.272
        }

        // set 2 token
        {
            uint80 wbtcPriceInfo = stickPrice(27880, 18, 6, 12, 10);
            (, uint256[] memory tokenPriceStable,) = d3Maker.getNSTokenInfo();
            uint256 newSlot = d3Maker.stickPrice(tokenPriceStable[0], 0, wbtcPriceInfo);
            newSlot = d3Maker.stickPrice(newSlot, 1, wbtcPriceInfo);

            uint256[] memory slotIndex = new uint256[](1);
            slotIndex[0] = 0;
            uint256[] memory priceSlots = new uint256[](1);
            priceSlots[0] = newSlot;
            vm.prank(owner);
            d3Maker.setNSPriceSlot(slotIndex, priceSlots, 0);

            // check
            (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token4));
            assertEq(tokenMMInfo.askUpPrice, 27913456 * (10 ** 15)); // 27913.456
            assertEq(tokenMMInfo.askDownPrice, 27896728 * (10 ** 15)); // 27896.728
            assertEq(tokenMMInfo.bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
            assertEq(tokenMMInfo.bidDownPrice, 35889539462559); // 1/27863.272
        }

        // prices and slots not match
        {
            uint256[] memory slotIndex = new uint256[](2);
            slotIndex[0] = slotIndex[1] = 0;
            uint256[] memory priceSlots = new uint256[](1);
            priceSlots[0] = 100000;

            vm.expectRevert(bytes("D3MAKER_PRICE_SLOT_LENGTH_NOT_MATCH"));
            vm.prank(owner);
            d3Maker.setNSPriceSlot(slotIndex, priceSlots, 0);
        }
    }

    function testSetAmounts() public {
        setAllTokenInfo();

        uint64 newAmount = stickAmount(40, 18, 40, 18);
        // set 1 token
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = newAmount;
        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        vm.prank(owner);
        d3Maker.setTokensAmounts(tokens, amounts);
        // check
        (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token1));
        assertEq(tokenMMInfo.askAmount, 40 * (10 ** 18));
        assertEq(tokenMMInfo.bidAmount, 40 * (10 ** 18));
        uint256 flag = d3MM.getTokenFlag(address(token1));
        assertEq(flag, 0);

        tokens = new address[](2);
        vm.expectRevert(bytes("D3MAKER_AMOUNTS_LENGTH_NOT_MATCH"));
        vm.prank(owner);
        d3Maker.setTokensAmounts(tokens, amounts);
    }

    function testSetKs() public {
        setAllTokenInfo();

        uint32 newK = stickKs(2000, 2000);
        uint32[] memory tokenKs = new uint32[](1);
        tokenKs[0] = newK;
        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        vm.prank(owner);
        d3Maker.setTokensKs(tokens, tokenKs);
        // check
        (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token1));
        assertEq(tokenMMInfo.kAsk, 2 * (10 ** 17));
        assertEq(tokenMMInfo.kBid, 2 * (10 ** 17));
        uint256 flag = d3MM.getTokenFlag(address(token1));
        assertEq(flag, 0);

        // k invalid
        newK = stickKs(10001, 2000);
        tokenKs[0] = newK;
        vm.expectRevert(bytes("D3MAKER_K_LIMIT_ERROR"));
        vm.prank(owner);
        d3Maker.setTokensKs(tokens, tokenKs);

        newK = stickKs(2000, 20001);
        tokenKs[0] = newK;
        vm.expectRevert(bytes("D3MAKER_K_LIMIT_ERROR"));
        vm.prank(owner);
        d3Maker.setTokensKs(tokens, tokenKs);

        // Ks and tokens not match
        tokens = new address[](2);
        vm.expectRevert(bytes("D3MAKER_K_LENGTH_NOT_MATCH"));
        vm.prank(owner);
        d3Maker.setTokensKs(tokens, tokenKs);
    }

    function testSetAmountsAndPrices() public {
        setAllTokenInfo();
        bytes[] memory mulData = new bytes[](2);

        uint64 newAmount = stickAmount(40, 18, 40, 18);
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = newAmount;
        address[] memory tokens = new address[](1);
        tokens[0] = address(token1);

        mulData[0] = abi.encodeWithSignature("setTokensAmounts(" "address[]," "uint64[]" ")", tokens, amounts);

        uint80 wbtcPriceInfo = stickPrice(27880, 18, 6, 12, 10);
        uint80[] memory priceInfos = new uint80[](1);
        priceInfos[0] = wbtcPriceInfo;

        mulData[1] = abi.encodeWithSignature("setTokensPrice(" "address[]," "uint80[]" ")", tokens, priceInfos);

        vm.prank(owner);
        d3Maker.multicall(mulData);

        //check
        (Types.TokenMMInfo memory tokenMMInfo,) = d3Maker.getTokenMMInfoForPool(address(token1));
        assertEq(tokenMMInfo.askUpPrice, 27913456 * (10 ** 15)); // 27913.456
        assertEq(tokenMMInfo.askDownPrice, 27896728 * (10 ** 15)); // 27896.728
        assertEq(tokenMMInfo.bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
        assertEq(tokenMMInfo.bidDownPrice, 35889539462559); // 1/27863.272
        assertEq(tokenMMInfo.askAmount, 40 * (10 ** 18));
        assertEq(tokenMMInfo.bidAmount, 40 * (10 ** 18));

        uint256 flag = d3MM.getTokenFlag(address(token1));
        assertEq(flag, 0);
    }

    function testSetHeartbeat() public {
        setAllTokenInfo();
        bool checkHB = d3Maker.checkHeartbeat();
        assertEq(checkHB, true);

        vm.prank(owner);
        d3Maker.setHeartbeat(300);

        (uint256 lastHeartBeat, uint256 maxInterval) = d3Maker.getHeartbeat();
        assertEq(lastHeartBeat, block.timestamp);
        assertEq(maxInterval, 300);

        vm.warp(302);
        checkHB = d3Maker.checkHeartbeat();
        assertEq(checkHB, false);
    }
}
