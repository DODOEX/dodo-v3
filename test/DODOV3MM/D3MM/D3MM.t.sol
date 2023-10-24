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


contract D3MMTest is TestContext {
    D3Maker public newD3Maker;
    address public newMakerAddr = address(567);

    struct SwapCallbackData {
        bytes data;
        address payer;
    }
    
    function setUp() public {
        contextBasic();
        setVaultAsset();
        setPoolAsset();
    }

    function testCreator() public {
        address creator = d3MM._CREATOR_();
        assertEq(creator, poolCreator);
    }

    function testFeeRate() public {
        uint256 feeRate = d3MM.getFeeRate(address(token1));
        assertEq(feeRate, 2* 1e14); //0.02%
    }

    function testGetD3MMInfo() public{
        (address tvault, address toracle, address tmaker, address tfeeRateModel, address tmaintainer) = 
            d3MM.getD3MMInfo();
        assertEq(tvault, address(d3Vault));
        assertEq(toracle, address(oracle));
        assertEq(tmaker, address(d3MakerWithPool));
        assertEq(tfeeRateModel, address(feeRateModel));
        assertEq(tmaintainer, address(maintainer));
    }

    function testTokenBalance() public {
        uint256 token1Balance = d3MM.getTokenReserve(address(token1));
        assertEq(token1Balance, 100* 1e8);
    }

    function testVersion() public {
        string memory ver = d3MM.version();
        assertEq(ver, "D3MM 1.0.0");
    }

    function testGetTokenList() public {
        address[] memory tokenlist = d3MM.getPoolTokenlist();
        assertEq(tokenlist.length, 4);
    }

    function testSetNewMaker() public {
        newD3Maker = new D3Maker();
        newD3Maker.init(newMakerAddr, address(d3MM), 100000);

        // check previous price
        uint256 beforeBalance2 = token2.balanceOf(user1);
        uint256 beforeBalance3 = token3.balanceOf(user1);

        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

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

        uint256 afterBalance2 = token2.balanceOf(user1);
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log(receiveToToken);
        assertEq(beforeBalance2 - afterBalance2, 1 ether);
        assertEq(afterBalance3 - beforeBalance3, receiveToToken);
        assertEq(afterBalance3 - beforeBalance3, 11978524479259449453); // 11.9, suppose 12
        (,,,,uint256 cumulativeAsk, uint256 cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 11990650771415848322);

        uint256 allFlag = d3MM.allFlag();
        assertEq(allFlag, 20);



        // setNewMaker
        vm.prank(poolCreator);
        d3MM.setNewMaker(address(newD3Maker));

        // check new maker state
        // set new param
        MakerTypes.TokenMMInfoWithoutCum memory token2Info = contructToken2MMInfo();
        vm.startPrank(newMakerAddr);
        newD3Maker.setNewToken(address(token2), true, token2Info.priceInfo, token2Info.amountInfo, token2Info.kAsk, token2Info.kBid);
        newD3Maker.setNewToken(address(token3), true, token2Info.priceInfo, token2Info.amountInfo, token2Info.kAsk, token2Info.kBid);
        vm.stopPrank();

        allFlag = d3MM.allFlag();
        assertEq(allFlag, 0);

        // check cumulative
        (,,,,cumulativeAsk, cumulativeBid) = d3MM.getTokenMMOtherInfoForRead(address(token2));
        assertEq(cumulativeAsk, 0);
        assertEq(cumulativeBid, 0);

        // check price
        (,uint256 receiveAmount , , ,) = d3MM.querySellTokens(address(token2), address(token3), 1 ether);
        assertEq(receiveAmount, 998194397280843196); // 0.99, suppose 1
    }
 }