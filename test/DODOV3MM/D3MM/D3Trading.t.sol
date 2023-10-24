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

contract D3TradingTest is TestContext {
    MockERC20 public tokenEx;
    MockChainlinkPriceFeed public tokenExChainLinkOracle;
    MockERC20 public token24;

    struct SwapCallbackData {
        bytes data;
        address payer;
    }

    function setUp() public {
        contextBasic();
        setVaultAsset();
        setPoolAsset();
    }

    function testReadFunctions() public {
        (uint256 askDownPrice, uint256 askUpPrice, uint256 bidDownPrice, uint256 bidUpPrice, uint256 swapFee) =
            d3MM.getTokenMMPriceInfoForRead(address(token2));
        assertEq(askDownPrice, 12007200000000000000);
        assertEq(askUpPrice, 12027600000000000000);
        assertEq(bidDownPrice, 83383363351344140);
        assertEq(bidUpPrice, 83458521115005843);
        assertEq(swapFee, 600000000000000);

        //console.log(askDownPrice);
        //console.log(askUpPrice);
        //console.log(bidDownPrice);
        //console.log(bidUpPrice);
        //console.log(swapFee);

        (uint256 askAmount, uint256 bidAmount, uint256 kAsk, uint256 kBid, uint256 cumulativeAsk, uint256 cumulativeBid)
        = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(askAmount, 30 * 1e18);
        assertEq(bidAmount, 30 * 1e18);
        assertEq(kAsk, 1e17);
        assertEq(kBid, 1e17);
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);
    }

    function testNormalSellTokens() public {
        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        uint256 gasleft1 = gasleft();
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token3),
            1 ether,
            0,
            abi.encode(swapData),
            block.timestamp + 1000
        );
        uint256 gasleft2 = gasleft();
        console.log("sellToken1stTime gas\t", gasleft1 - gasleft2);

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log(receiveToToken);
        assertEq(beforeBalance2 - afterBalance2, 1 ether);
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 11978524479259449453);
    }

    function testNormalSellTokens_LpFeeRateZero() public {
        ( , ,address poolMaker, , ) = d3MM.getD3MMInfo();
        d3MakerWithPool = D3Maker(poolMaker);
        vm.startPrank(maker);

        address[] memory tokenList = new address[](1);
        tokenList[0] = address(token2);
        uint80[] memory priceList = new uint80[](1);
        priceList[0] = stickPrice(12, 18, 0, 23, 15);
        d3MakerWithPool.setTokensPrice(tokenList, priceList);
        vm.stopPrank();

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        uint256 gasleft1 = gasleft();
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token3),
            1 ether,
            0,
            abi.encode(swapData),
            block.timestamp + 1000
        );
        uint256 gasleft2 = gasleft();
        console.log("sellToken1stTime gas\t", gasleft1 - gasleft2);

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log(receiveToToken);
        assertEq(beforeBalance2 - afterBalance2, 1 ether);
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 11984294018423130017);
    }

    function testNormalBuyTokens() public {
        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        uint256 gasleft1 = gasleft();
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token3),
            1 ether,
            30 ether,
            abi.encode(swapData),
            block.timestamp + 1000
        );
        uint256 gasleft2 = gasleft();
        console.log("buyToken1stTime gas\t", gasleft1 - gasleft2);

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log(beforeBalance2 - afterBalance2);
        //console.log(afterBalance3 - beforeBalance3);

        assertEq(beforeBalance2 - afterBalance2, receiveToToken);
        assertEq(beforeBalance2 - afterBalance2, 83468096707748715); // 0.08
        assertEq(afterBalance3 - beforeBalance3, 1 ether);
    }

    function testNormalBuyTokens_LpFeeRateZero() public {
        ( , ,address poolMaker, , ) = d3MM.getD3MMInfo();
        d3MakerWithPool = D3Maker(poolMaker);
        vm.startPrank(maker);

        address[] memory tokenList = new address[](1);
        tokenList[0] = address(token2);
        uint80[] memory priceList = new uint80[](1);
        priceList[0] = stickPrice(12, 18, 0, 23, 15);
        d3MakerWithPool.setTokensPrice(tokenList, priceList);
        vm.stopPrank();

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        uint256 gasleft1 = gasleft();
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token3),
            1 ether,
            30 ether,
            abi.encode(swapData),
            block.timestamp + 1000
        );
        uint256 gasleft2 = gasleft();
        console.log("buyToken1stTime gas\t", gasleft1 - gasleft2);

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log(beforeBalance2 - afterBalance2);
        //console.log(afterBalance3 - beforeBalance3);

        assertEq(beforeBalance2 - afterBalance2, receiveToToken);
        assertEq(beforeBalance2 - afterBalance2, 83418837585988938); // 0.08
        assertEq(afterBalance3 - beforeBalance3, 1 ether);
    }

    function testTransferInNotEnough() public {
        vm.startPrank(user1);
        token2.approve(address(dodoApprove), 10**14);
        token3.approve(address(dodoApprove), 10**17);
        vm.stopPrank();

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        // approve not enough
        vm.expectRevert();
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            13 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        vm.expectRevert();
        vm.prank(user1);
        receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // d3mm balance not enough
        faucetToken(address(token2), address(d3MM), 10 ** 14);
        vm.expectRevert(bytes("D3MM_FROMAMOUNT_NOT_ENOUGH"));
        receiveToToken = failD3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            13 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        faucetToken(address(token2), address(d3MM), 10 ** 17);
        vm.expectRevert(bytes("D3MM_FROMAMOUNT_NOT_ENOUGH"));
        receiveToToken = failD3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // success test

        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);
        (, , , , , uint256 cumulativeBid)
        = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeBid, 0);

        receiveToToken = failD3Proxy.buyTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            13 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        assertEq(beforeBalance2 - afterBalance2, 1000); 
        assertEq(afterBalance3 - beforeBalance3, 1000000000000000000);

        (, , , , , cumulativeBid)
        = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeBid, 1001001236331550199); // 1.001 suppose 1 vusd
        //console.log("cumualativeBid:", cumulativeBid);

        beforeBalance2 = afterBalance2;
        beforeBalance3 = afterBalance3;

        faucetToken(address(token2), address(d3MM), 10 ** 18);
        receiveToToken = failD3Proxy.sellTokens(
            address(d3MM),
            user1, 
            address(token2), 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        afterBalance2 = token2.balanceOf(user1);
        afterBalance3 = token3.balanceOf(user1);

        //console.log(receiveToToken);
        assertEq(beforeBalance2 - afterBalance2, 1000); 
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 11978141873757971225); // suppose 12
    }

    function testMinMaxRevert() public {
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        vm.expectRevert(bytes("D3MM_MAXPAYAMOUNT_NOT_ENOUGH"));
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token3),
            1 ether,
            0.02 ether,
            abi.encode(swapData),
            block.timestamp + 1000
        );

        vm.expectRevert(bytes("D3MM_MINRESERVE_NOT_ENOUGH"));
        vm.prank(user1);
        receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token3),
            1 ether,
            13 ether,
            abi.encode(swapData),
            block.timestamp + 1000
        );
    }

    function testHeartBeatFail() public {
        vm.warp(1000001);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        vm.expectRevert(bytes("D3MM_HEARTBEAT_CHECK_FAIL"));
        vm.prank(user1);
        d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token3),
            1 ether,
            12 ether,
            abi.encode(swapData),
            block.timestamp + 1000
        );
    }

    function testBelowIM() public {
        vm.startPrank(poolCreator);
        d3MM.makerWithdraw(poolCreator, address(token1), 100 * 1e8);
        d3MM.makerWithdraw(poolCreator, address(token2), 96 * 1e18);
        d3MM.makerWithdraw(poolCreator, address(token3), 100 * 1e18);
        d3MM.borrow(address(token2), 9 * 1e18);
        vm.stopPrank();

        // change token2 amount
        uint64 newAmount = stickAmount(4000, 18, 4000, 18);
        uint64[] memory amounts = new uint64[](1);
        amounts[0] = newAmount;
        address[] memory tokens = new address[](1);
        tokens[0] = address(token2);
        vm.prank(maker);
        d3MakerWithPool.setTokensAmounts(tokens, amounts);

        // create and set tokenEx oracle
        tokenEx = new MockERC20("TokenEx", "TKEx", 18);
        tokenExChainLinkOracle = new MockChainlinkPriceFeed("TokenEx/USD", 18);
        tokenExChainLinkOracle.feedData(24 * 1e18);
        oracle.setPriceSource(
            address(tokenEx), PriceSource(address(tokenExChainLinkOracle), true, 5 * (10 ** 17), 18, 18, 3600)
        );

        // deposit tokenEx
        tokenEx.mint(poolCreator, 1000 * 1e18);
        vm.prank(poolCreator);
        tokenEx.approve(address(dodoApprove), type(uint256).max);
        vm.prank(poolCreator);
        d3Proxy.makerDeposit(address(d3MM), address(tokenEx), 100 * 1e18);

        // mint user1
        tokenEx.mint(user1, 1000 * 1e18);
        vm.prank(user1);
        tokenEx.approve(address(dodoApprove), type(uint256).max);

        
        
        // set tokenex info
        MakerTypes.TokenMMInfoWithoutCum memory tokenInfo;
        tokenInfo.priceInfo = stickPrice(24, 18, 6, 12, 10);
        tokenInfo.amountInfo = stickAmount(3000, 18, 3000, 18);
        tokenInfo.kAsk = tokenInfo.kBid = 1000;
        //tokenInfo.decimal = 18;
        vm.prank(maker);
        d3MakerWithPool.setNewToken(address(tokenEx), true, tokenInfo.priceInfo, tokenInfo.amountInfo, tokenInfo.kAsk, tokenInfo.kBid);

        // now pool has 4+10 token2, 100 tokenEx
        // cr = 4 / 0 = max, safe
        // if user buy 3.9 ether token2, pool safe
        // if user buy 4.1 ether token2, pool unsafe, revert

        // pool safe swap
        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalanceEx = tokenEx.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        vm.prank(user1);
        d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(tokenEx),
            address(token2),
            1 ether,
            3 ether,
            abi.encode(swapData),
            block.timestamp + 1000
        );

        vm.prank(user1);
        d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(tokenEx),
            address(token2),
            0.5 ether,
            0,
            abi.encode(swapData),
            block.timestamp + 1000
        );
        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalanceEx = tokenEx.balanceOf(user1);
        
        assertEq(afterBalance2 - beforeBalance2, 1998398178385100244); // 1.99 near 2
        assertEq(beforeBalanceEx - afterBalanceEx, 1000801105666936279); // 1.00 near 1
        //console.log(afterBalance2 - beforeBalance2);
        //console.log(beforeBalanceEx - afterBalanceEx);

        uint256 token2Res = d3MM.getTokenReserve(address(token2));
        //console.log("token2Res:", token2Res);
        assertEq(token2Res, 11000802302535914122); // 11.0 > borrow 10
        uint256 colR = d3Vault.getCollateralRatio(address(d3MM));
        //console.log(colR);
        assertEq(colR, type(uint256).max);

        // pool unsafe swap
        vm.expectRevert(bytes("D3MM_BELOW_IM_RATIO"));
        vm.prank(user1);
        d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(tokenEx),
            address(token2),
            10 ether,
            0,
            abi.encode(swapData),
            block.timestamp + 1000
        );

        vm.expectRevert(bytes("D3MM_BELOW_IM_RATIO"));
        vm.prank(user1);
        d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(tokenEx),
            address(token2),
            5 ether,
            10 ether,
            abi.encode(swapData),
            block.timestamp + 1000
        );
    }

    function setRealParam() public {
        token1ChainLinkOracle.feedData(30647 * 1e18);
        token2ChainLinkOracle.feedData(1 * 1e18);
        vm.startPrank(maker);
        uint32[] memory tokenKs = new uint32[](2);
        tokenKs[0] = 0;
        tokenKs[1] = (1<< 16) +1;
        address[] memory tokens = new address[](2);
        tokens[0] = address(token2);
        tokens[1] = address(token1);
        address[] memory slotIndex = new address[](2);
        slotIndex[0] = address(token1);
        slotIndex[1] = address(token2);
        uint80[] memory priceSlot = new uint80[](2);
        priceSlot[0] = 2191925019632266903652;
        priceSlot[1] = 720435765840878108682;

        uint64[] memory amountslot = new uint64[](2);
        amountslot[0] = stickAmount(10,18, 40000, 19);
        amountslot[1] = stickAmount(40000, 19, 40000, 19); // use 40000, 19 not (400000, 18)
        d3MakerWithPool.setTokensKs(tokens, tokenKs);
        d3MakerWithPool.setTokensPrice(slotIndex, priceSlot);
        d3MakerWithPool.setTokensAmounts(slotIndex, amountslot);
        vm.stopPrank();
    }

    // sell dec 8 to dec 18
    function testQueryDec8WithHighPrice() public {
        setRealParam();

        (uint256 askDownPrice, uint256 askUpPrice, uint256 bidDownPrice, uint256 bidUpPrice, uint256 swapFee) =
            d3MM.getTokenMMPriceInfoForRead(address(token1));
        assertEq(askDownPrice, 30449419000000000000000);
        assertEq(askUpPrice, 30723190000000000000000);
        assertEq(bidDownPrice, 32907097570631);
        assertEq(bidUpPrice, 33206253003091);
        assertEq(swapFee, 1000000000000000);

        //console.log(askDownPrice);
        //console.log(askUpPrice);
        //console.log(bidDownPrice);
        //console.log(bidUpPrice);
        //console.log(swapFee);

        (,,uint kask, uint kbid,,) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        assertEq(kask, 1e14);
        assertEq(kbid, 1e14);

        (askDownPrice, askUpPrice, bidDownPrice, bidUpPrice, swapFee) =
            d3MM.getTokenMMPriceInfoForRead(address(token2));
        assertEq(askDownPrice, 999800000000000000);
        assertEq(askUpPrice, 1000799800000000000);
        assertEq(bidDownPrice, 1000200040008001601);
        assertEq(bidUpPrice, 1001201241249250852);
        assertEq(swapFee, 0);

        (,,kask, kbid,,) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(kask, 0);
        assertEq(kbid, 0);

        //console.log(askDownPrice);
        //console.log(askUpPrice);
        //console.log(bidDownPrice);
        //console.log(bidUpPrice);
        //console.log(swapFee);
        //console.log(kask);
        //console.log(kbid);

        uint256 balance2 = d3MM.getTokenReserve(address(token2));
        //console.log("pool balance token2:", balance2);
        assertEq(balance2, 100 ether);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        //uint256 gasleft1 = gasleft();
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token1),
            address(token2),
            1000000,
            0,
            abi.encode(swapData),
            block.timestamp + 1000
        );
        // token2's balance max 100 ether
        assertEq(receiveToToken, 99960000000000000000);

        (,,, ,uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeAsk, 100060000000000000000);
        assertEq(cumulativeBid, 0);
        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        assertEq(cumulativeBid, 303885789307408018586);
        assertEq(cumulativeAsk, 0);

        token2.mint(address(d3MM), 400 ether);
        d3MM.makerDeposit(address(token2));

        vm.prank(user1);
        receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token1),
            address(token2),
            1000000,
            0,
            abi.encode(swapData),
            block.timestamp + 1000
        );

        assertEq(receiveToToken, 303824958558415332845);

        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeAsk, 404188905095588617491);
        //console.log(cumulativeAsk - 100 ether);
        assertEq(cumulativeBid, 0);
        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        assertEq(cumulativeBid, 607771537173258008457);
        //console.log(cumulativeBid - 303823704036065356124);
        assertEq(cumulativeAsk, 0);
    }

    function testSellDec18ToDec8() public {
        setRealParam();
        token2.mint(user1, 400 ether);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        //normal sell
        {
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token1),
            100 ether,
            0,
            abi.encode(swapData),
            block.timestamp + 1000
        );

        assertEq(receiveToToken, 328216); //0.00328, near 0.00329

        (,,, ,uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        assertEq(cumulativeAsk, 3285440000000000); //0.00328 ether
        //console.log(cumulativeAsk);
        assertEq(cumulativeBid, 0);
        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeBid, 99979999999999999900);
        //console.log(cumulativeBid);
        assertEq(cumulativeAsk, 0);

        (uint256 askAmount,uint256 bidAmount,, ,, ) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(askAmount, 400000 ether);
        assertEq(bidAmount, 400000 ether);

        /*
        vm.prank(user1);
        receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token1),
            1000000000000,
            0,
            abi.encode(swapData),
            block.timestamp + 1000
        );
        console.log("receiveTo:", receiveToToken);
        */
        }

        

        // limit sell, from bid cumulative = real amount > to ask cumulative(limit)
        {
        {
        address[] memory slotIndex = new address[](2);
        slotIndex[0] = address(token1);
        slotIndex[1] = address(token2);
        uint64[] memory amountslot = new uint64[](2);
        amountslot[0] = stickAmount(1,18, 40000, 18);
        amountslot[1] = stickAmount(40000, 18, 40000, 18); 
        vm.prank(maker);
        d3MakerWithPool.setTokensAmounts(slotIndex, amountslot);
        token2.mint(user1, 40000 ether);
        }

        (,,, ,uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeBid, 0);

        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token1),
            40000 ether,
            0,
            abi.encode(swapData),
            block.timestamp + 1000
        );

        //uint256 balance2 = d3MM.getTokenReserve(address(token1));
        //console.log("pool balance token1:", balance2);
        assertEq(receiveToToken, 99960000);

        (,,, , cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        //assertEq(cumulativeAsk, 3282160000000000); //0.00328 ether
        assertEq(cumulativeAsk, 1000600000000000000);
        assertEq(cumulativeBid, 0);
        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        //assertEq(cumulativeBid, 99960003999999999900);
        assertEq(cumulativeBid, 39991999999999999960000);
        //assertEq(cumulativeBid, );
        assertEq(cumulativeAsk, 0);
        }
    }

    function testBuyDec8WithDec18() public {
        setRealParam();
        token2.mint(user1, 400 ether);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        //normal buy
        {
        vm.prank(user1);
        uint256 payFromToken = d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token1),
            address(token2),
            1 ether,
            100000,
            abi.encode(swapData),
            block.timestamp + 1000
        );

        //console.log(payFromToken);
        assertEq(payFromToken, 3291); 

        (,,, ,uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeAsk, 1001000000000000000); // 1 ether
        //console.log(cumulativeAsk);
        assertEq(cumulativeBid, 0);
        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        assertEq(cumulativeBid, 1000199920000000000); // 1 ether
        //console.log(cumulativeBid);
        assertEq(cumulativeAsk, 0);
        }

        // over buy, > balance reserve
        {
        address[] memory slotIndex = new address[](2);
        slotIndex[0] = address(token1);
        slotIndex[1] = address(token2);
        uint64[] memory amountslot = new uint64[](2);
        amountslot[0] = stickAmount(1,18, 40000, 18);
        amountslot[1] = stickAmount(400, 18, 40000, 18); 
        vm.prank(maker);
        d3MakerWithPool.setTokensAmounts(slotIndex, amountslot);
        token2.mint(user1, 40000 ether);
        }

        token1.mint(user1, 1e9);
        vm.expectRevert(bytes("D3MM_BALANCE_NOT_ENOUGH"));
        vm.prank(user1);
        d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token1),
            address(token2),
            410 ether,
            100000000,
            abi.encode(swapData),
            block.timestamp + 1000
        );

    }

    function testBuyDec18WithDec8() public {
        setRealParam();
        token2.mint(user1, 400 ether);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        //normal buy
        {
        vm.prank(user1);
        uint256 payFromToken = d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token1),
            1000000,
            400 ether,
            abi.encode(swapData),
            block.timestamp + 1000
        );

        //console.log(payFromToken);
        assertEq(payFromToken, 304676950368205693279); 

        (,,, ,uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        assertEq(cumulativeAsk, 10010000000000000); // 0.01 ether
        //console.log(cumulativeAsk);
        assertEq(cumulativeBid, 0);
        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeBid, 304616014978132051934); // 304 ether
        //console.log(cumulativeBid);
        assertEq(cumulativeAsk, 0);
        }

        // over buy, > set amount
        {
        address[] memory slotIndex = new address[](2);
        slotIndex[0] = address(token1);
        slotIndex[1] = address(token2);
        uint64[] memory amountslot = new uint64[](2);
        amountslot[0] = stickAmount(1,16, 40000, 18);
        amountslot[1] = stickAmount(400, 18, 40000, 18); 
        vm.prank(maker);
        d3MakerWithPool.setTokensAmounts(slotIndex, amountslot);
        token2.mint(user1, 40000 ether);
        

        token1.mint(user1, 1e9);
        vm.expectRevert(bytes("PMMRO_VAULT_RESERVE_NOT_ENOUGH"));
        vm.prank(user1);
        d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token2),
            address(token1),
            2000000,
            400 ether,
            abi.encode(swapData),
            block.timestamp + 1000
        );

        (,,, ,uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        assertEq(cumulativeAsk, 0); 
        //console.log(cumulativeAsk);
        assertEq(cumulativeBid, 0);
        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeBid, 0);
        //console.log(cumulativeBid);
        assertEq(cumulativeAsk, 0);
        }
    }

    function testSwapDec8ToDec24() public {
        // create 24 bit token
        
        token24 = new MockERC20("Token24", "TK24", 24);
        oracle.setPriceSource(
            address(token24), PriceSource(address(token3ChainLinkOracle), true, 5 * (10 ** 17), 18, 24, 3600)
        ); // price 1
        token24.mint(user1, 300 * 1e24);

        // pool config
        token24.mint(address(d3MM), 240 * 1e24);
        d3MM.makerDeposit(address(token24));
        uint256 balance24 = d3MM.getTokenReserve(address(token24));
        assertEq(balance24, 240 * 1e24);

        MakerTypes.TokenMMInfoWithoutCum memory token3Info = contructToken3MMInfo();
        vm.prank(maker);
        d3MakerWithPool.setNewToken(address(token24), true, token3Info.priceInfo, token3Info.amountInfo, token3Info.kAsk, token3Info.kBid);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        // token1 = 1300, buy 24
        vm.prank(user1);
        uint256 payFromToken = d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token1),
            address(token24),
            10 * 1e24,
            10000000, //1 token1
            abi.encode(swapData),
            block.timestamp + 1000
        );
        //console.log(payFromToken);
        assertEq(payFromToken, 770475);  //0.077

        (,,, ,uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token24));
        assertEq(cumulativeAsk, 10012000000000000000); // 10 ether
        //console.log(cumulativeAsk);
        assertEq(cumulativeBid, 0);
        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        assertEq(cumulativeBid, 10010102042080981350); // 10 ether
        //console.log(cumulativeBid);
        assertEq(cumulativeAsk, 0);

        // sell 8 to 24
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token1),
            address(token24),
            1000000,
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );
        //console.log(receiveToToken);
        assertEq(receiveToToken, 12978504141578036786079600 );  //12.9 token24

        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token24));
        assertEq(cumulativeAsk, 23006084578722788330); // 22 ether, this time = 12.9 ether
        //console.log(cumulativeAsk);
        assertEq(cumulativeBid, 0);
        (,,, ,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token1));
        assertEq(cumulativeBid, 23002016635982823165); // 23 ether, this time = 13 ether
        //console.log(cumulativeBid);
        assertEq(cumulativeAsk, 0);
    }

    function testExtraFee() public {
        vm.prank(owner);
        feeRateModel.setDefaultFeeRate(0);

        token2ChainLinkOracle.feedData(212 * 1e18);
        token3ChainLinkOracle.feedData(1 * 1e18);

        address[] memory tokens = new address[](2);
        uint64[] memory amounts = new uint64[](2);
        uint80[] memory prices = new uint80[](2);
        uint32[] memory ks = new uint32[](2);

        tokens[0] = address(token3); //usdt
        tokens[1] = address(token2); //bnb
        amounts[0] = stickAmount(60000, 18, 60000, 18);
        amounts[1] = stickAmount(400, 18, 60000, 18);
        prices[0] = stickPrice(10000, 14, 1, 2, 2);
        prices[1] = stickPrice(21195, 16, 2, 100, 100);
        ks[0] = stickKs(1, 1);
        ks[1] = stickKs(1, 1);

        vm.startPrank(maker);
        d3MakerWithPool.setTokensAmounts(tokens, amounts);
        d3MakerWithPool.setTokensKs(tokens, ks);
        d3MakerWithPool.setTokensPrice(tokens, prices);
        vm.stopPrank();

        Types.TokenMMInfo memory tokenMMInfo;
        uint256 tokenIndex;
        (tokenMMInfo, tokenIndex) = d3MakerWithPool.getTokenMMInfoForPool(address(token3));
        assertEq(tokenMMInfo.askUpPrice, 1000200000000000000);
        assertEq(tokenMMInfo.askDownPrice, 1000100000000000000);
        assertEq(tokenMMInfo.bidUpPrice, 1000200040008001601);
        assertEq(tokenMMInfo.bidDownPrice, 1000100010001000101);

        console.log("query");
        (uint256 fromAmount, uint256 toAmount, uint256 vusd, ,) = d3MM.querySellTokens(address(token2), address(token3), 10000);
        assertEq(toAmount, 2118866);
        assertEq(vusd, 2119077);

        // test lp fee =0
        prices[0] = stickPrice(10000, 14, 0, 2, 2);
        prices[1] = stickPrice(21195, 16, 0, 100, 100);
        vm.startPrank(maker);
        d3MakerWithPool.setTokensPrice(tokens, prices);
        vm.stopPrank();

        (fromAmount, toAmount, vusd, ,) = d3MM.querySellTokens(address(token2), address(token3), 10000);
        assertEq(toAmount, 2119501);
        assertEq(vusd, 2119501);
    }
}
