/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";
import {Types} from "contracts/DODOV3MM/lib/Types.sol";
import {D3Maker} from "D3Pool/D3Maker.sol";
import {D3MakerFreeSlot} from "contracts/DODOV3MM/D3PoolNoBorrow/D3MakerFreeSlot.sol";
import {D3MMNoBorrow} from "contracts/DODOV3MM/D3PoolNoBorrow/D3MMNoBorrow.sol";

contract D3MMNoBorrowTest is TestContext {
    D3MMNoBorrow public d3MMNoBorrow;
    D3MakerFreeSlot public d3MakerFreeSlotWithPool;
    D3MakerFreeSlot public newD3Maker;
    address public newMakerAddr = address(567);

    bytes32 public version = keccak256(abi.encodePacked("D3MMNoBorrow 1.0.0"));

    MockERC20 public token5;

    struct SwapCallbackData {
        bytes data;
        address payer;
    }

    event ReplaceToken(address indexed oldToken, address indexed newToken);

    function setUp() public {
        contextBasic();
        setVaultAsset();
        setPoolAsset();
        d3MMFactory.setD3Temp(1, address(new D3MMNoBorrow()));
        d3MMFactory.setD3MakerTemp(1, address(new D3MakerFreeSlot()));
        d3MMNoBorrow = D3MMNoBorrow(d3MMFactory.breedD3Pool(poolCreator, maker, 100000, 1));
        vm.label(address(d3MMNoBorrow), "d3MMNoBorrow");

        (,, address poolMaker,,) = d3MMNoBorrow.getD3MMInfo();
        d3MakerFreeSlotWithPool = D3MakerFreeSlot(poolMaker);

        token5 = new MockERC20("Token 5", "TK5", 18);
        vm.label(address(token5), "token5");

        token1.mint(address(d3MMNoBorrow), 100 * 1e8);
        token2.mint(address(d3MMNoBorrow), 100 * 1e18);
        token3.mint(address(d3MMNoBorrow), 100 * 1e18);
        token5.mint(address(d3MMNoBorrow), 100 * 1e18);
        vm.startPrank(poolCreator);
        d3MMNoBorrow.makerDeposit(address(token1));
        d3MMNoBorrow.makerDeposit(address(token2));
        d3MMNoBorrow.makerDeposit(address(token3));
        d3MMNoBorrow.makerDeposit(address(token5));
        vm.stopPrank();

        // set token price
        MakerTypes.TokenMMInfoWithoutCum memory token1Info = contructToken1Dec8MMInfo();
        MakerTypes.TokenMMInfoWithoutCum memory token2Info = contructToken2MMInfo();
        MakerTypes.TokenMMInfoWithoutCum memory token3Info = contructToken3MMInfo();
        MakerTypes.TokenMMInfoWithoutCum memory token5Info = contructToken2MMInfo();

        vm.startPrank(maker);
        d3MakerFreeSlotWithPool.setNewToken(
            address(token1), true, token1Info.priceInfo, token1Info.amountInfo, token1Info.kAsk, token1Info.kBid
        );
        d3MakerFreeSlotWithPool.setNewToken(
            address(token2), true, token2Info.priceInfo, token2Info.amountInfo, token2Info.kAsk, token2Info.kBid
        );
        d3MakerFreeSlotWithPool.setNewToken(
            address(token3), true, token3Info.priceInfo, token3Info.amountInfo, token3Info.kAsk, token3Info.kBid
        );
        d3MakerFreeSlotWithPool.setNewToken(
            address(weth), true, token2Info.priceInfo, token2Info.amountInfo, token2Info.kAsk, token2Info.kBid
        );
        d3MakerFreeSlotWithPool.setNewToken(
            address(token5), false, token5Info.priceInfo, token5Info.amountInfo, token5Info.kAsk, token5Info.kBid
        );
        vm.stopPrank();

        oracle.setWhitelistVersion(version, true);
    }

    function testVersion() public {
        string memory ver = d3MMNoBorrow.version();
        assertEq(ver, "D3MMNoBorrow 1.0.0");
    }

    function testQueryNoWhitelistToken() public {
        console2.logBytes32(version);

        (, uint256 toAmount,,,) = d3MMNoBorrow.querySellTokens(address(token2), address(token5), 10000);
        assertEq(toAmount, 9987);
    }

    function testBorrow() public {
        vm.prank(poolCreator);
        vm.expectRevert(bytes("Borrow Not Allowed"));
        d3MMNoBorrow.borrow(address(token1), 1000);
    }

    function testRepay() public {
        vm.prank(poolCreator);
        vm.expectRevert(bytes("Repay Not Allowed"));
        d3MMNoBorrow.repay(address(token1), 1000);
    }

    function testRepayAll() public {
        vm.prank(poolCreator);
        vm.expectRevert(bytes("Repay Not Allowed"));
        d3MMNoBorrow.repayAll(address(token1));
    }

    function testMakerDeposit() public {
        uint256 token5ReserveBefore = d3MMNoBorrow.getTokenReserve(address(token5));
        token5.mint(address(d3MMNoBorrow), 1234);
        vm.prank(poolCreator);
        d3MMNoBorrow.makerDeposit(address(token5));
        uint256 token5ReserveAfter = d3MMNoBorrow.getTokenReserve(address(token5));
        assertEq(token5ReserveAfter - token5ReserveBefore, 1234);
    }

    function testSetNewTokenOnOccupiedSlot() public {
        MockERC20 token6 = new MockERC20("Token 6", "TK6", 18);
        MakerTypes.TokenMMInfoWithoutCum memory token6Info = contructToken1MMInfo();

        vm.prank(maker);
        vm.expectRevert(bytes("D3MAKER_OLD_TOKEN_NOT_FOUND"));
        d3MakerFreeSlotWithPool.setNewTokenAndReplace(
            address(token6),
            true,
            token6Info.priceInfo,
            token6Info.amountInfo,
            token6Info.kAsk,
            token6Info.kBid,
            address(token4)
        );

        vm.prank(maker);
        vm.expectEmit(true, true, true, true);
        emit ReplaceToken(address(token1), address(token6));
        d3MakerFreeSlotWithPool.setNewTokenAndReplace(
            address(token6),
            true,
            token6Info.priceInfo,
            token6Info.amountInfo,
            token6Info.kAsk,
            token6Info.kBid,
            address(token1) // replace token1's slot
        );

        Types.TokenMMInfo memory tokenMMInfo;
        uint256 tokenIndex;
        (tokenMMInfo, tokenIndex) = d3MakerFreeSlotWithPool.getTokenMMInfoForPool(address(token6));
        assertEq(tokenMMInfo.askUpPrice, 130156 * (10 ** 16));
        assertEq(tokenMMInfo.askDownPrice, 130078 * (10 ** 16));
        assertEq(tokenMMInfo.bidUpPrice, 770000770000771); //1298.7
        assertEq(tokenMMInfo.bidDownPrice, 769692584781639); // 1299.22
        assertEq(tokenMMInfo.askAmount, 30 * (10 ** 18));
        assertEq(tokenMMInfo.bidAmount, 30 * (10 ** 18));
        assertEq(tokenIndex, 0);

        // token1 is replaced, so the index of token6 is 0
        uint256 index = uint256(d3MakerFreeSlotWithPool.getOneTokenOriginIndex(address(token6)));
        assertEq(index, 0);

        MockERC20 token7 = new MockERC20("Token 7", "TK7", 18);
        MakerTypes.TokenMMInfoWithoutCum memory token7Info = contructToken1MMInfo();

        vm.prank(maker);
        vm.expectEmit(true, true, true, true);
        emit ReplaceToken(address(token2), address(token7));
        d3MakerFreeSlotWithPool.setNewTokenAndReplace(
            address(token7),
            true,
            token7Info.priceInfo,
            token7Info.amountInfo,
            token7Info.kAsk,
            token7Info.kBid,
            address(token2) // replace token2's slot
        );

        // token2 is replaced, so the index of token7 is 2
        uint256 indexOfToken7 = uint256(d3MakerFreeSlotWithPool.getOneTokenOriginIndex(address(token7)));
        assertEq(indexOfToken7, 2);

        MockERC20 token8 = new MockERC20("Token 8", "TK8", 18);
        MakerTypes.TokenMMInfoWithoutCum memory token8Info = contructToken1MMInfo();

        vm.prank(maker);
        vm.expectRevert(bytes("D3MAKER_STABLE_TYPE_NOT_MATCH"));
        d3MakerFreeSlotWithPool.setNewTokenAndReplace(
            address(token8),
            true,
            token8Info.priceInfo,
            token8Info.amountInfo,
            token8Info.kAsk,
            token8Info.kBid,
            address(token5) // replace token5's slot
        );

        vm.prank(maker);
        vm.expectEmit(true, true, true, true);
        emit ReplaceToken(address(token5), address(token8));
        d3MakerFreeSlotWithPool.setNewTokenAndReplace(
            address(token8),
            false,
            token8Info.priceInfo,
            token8Info.amountInfo,
            token8Info.kAsk,
            token8Info.kBid,
            address(token5) // replace token5's slot
        );

        // token5 is the first unstable coin, and is replaced, so the index of token8 is 1
        uint256 indexOfToken8 = uint256(d3MakerFreeSlotWithPool.getOneTokenOriginIndex(address(token8)));
        assertEq(indexOfToken8, 1);
    }

    // test if maker can still withdraw a token if a token is replaced by new token
    function testWithdrawAfterReplaceToken() public {
        MockERC20 token6 = new MockERC20("Token 6", "TK6", 18);
        MakerTypes.TokenMMInfoWithoutCum memory token6Info = contructToken1MMInfo();
        vm.prank(maker);
        d3MakerFreeSlotWithPool.setNewTokenAndReplace(
            address(token6),
            true,
            token6Info.priceInfo,
            token6Info.amountInfo,
            token6Info.kAsk,
            token6Info.kBid,
            address(token1) // replace token1's slot
        );

        uint256 token1BalanceBefore = token1.balanceOf(address(this));
        vm.prank(poolCreator);
        d3MMNoBorrow.makerWithdraw(address(this), address(token1), 3321);
        uint256 token1BalanceAfter = token1.balanceOf(address(this));
        assertEq(token1BalanceAfter - token1BalanceBefore, 3321);
    }

    function test_SellTokens() public {
        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        uint256 gasleft1 = gasleft();
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.sellTokens(
            address(d3MMNoBorrow),
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

    function test_BuyTokens() public {
        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        uint256 gasleft1 = gasleft();
        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MMNoBorrow),
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
}
