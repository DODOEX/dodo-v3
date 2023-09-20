/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";
import "mock/MockD3Pool.sol";
import {Types} from "contracts/DODOV3MM/lib/Types.sol";
import {PMMRangeOrder} from "contracts/DODOV3MM/lib/PMMRangeOrder.sol";
import {D3Maker} from "D3Pool/D3Maker.sol";
import {PMMPricing} from "contracts/DODOV3MM/lib/PMMPricing.sol";
import {DODOMath} from "contracts/DODOV3MM/lib/DODOMath.sol";

// This helper contract exposes internal library functions for coverage to pick up
// check this link: https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086
contract PMMRangeOrderHelper is Test {
    function querySellTokens(
        Types.RangeOrderState memory roState,
        address fromToken,
        address toToken,
        uint256 fromTokenAmount
    ) public view returns (uint256, uint256, uint256) { 
        (uint256 fromAmount, uint256 receiveToToken, uint256 vusdAmount) = PMMRangeOrder.querySellTokens(roState, fromToken, toToken, fromTokenAmount);
        return (fromAmount, receiveToToken, vusdAmount);
    }

    function queryBuyTokens(
        Types.RangeOrderState memory roState,
        address fromToken,
        address toToken,
        uint256 toTokenAmount
    ) public view returns (uint256, uint256, uint256) {
        (uint256 payFromToken, uint256 toAmount, uint256 vusdAmount) = PMMRangeOrder.queryBuyTokens(roState, fromToken, toToken, toTokenAmount);
        return (payFromToken, toAmount, vusdAmount);
    }

    // ============querybuy for lib =======================

    function queryBuyTokensLoc(Types.RangeOrderState memory roState,
        address fromToken,
        address toToken,
        uint256 toTokenAmount
    ) public view returns (uint256 payFromToken, uint256 toAmount, uint256 vusdAmount) {
        // contruct fromToken to vUSD
        uint256 payVUSD;
        {
            PMMPricing.PMMState memory toTokenState = PMMRangeOrder._contructTokenState(roState, false, true);
            // vault reserve protect
            require(
                toTokenAmount <= toTokenState.BMaxAmount - roState.toTokenMMInfo.cumulativeAsk, "PMMRO_VAULT_RESERVE_NOT_ENOUGH"
            );
            payVUSD = queryBuyBaseTokenForLib(toTokenState, toTokenAmount);
        }

        // construct vUSD to toToken
        {
            PMMPricing.PMMState memory fromTokenState = PMMRangeOrder._contructTokenState(roState, true, false);
            payFromToken = queryBuyBaseTokenForMath(fromTokenState, payVUSD);
        }

        // oracle protect
        {
            uint256 oracleToAmount = ID3Oracle(roState.oracle).getMaxReceive(fromToken, toToken, payFromToken);
            require(oracleToAmount >= toTokenAmount, "PMMRO_ORACLE_PRICE_PROTECTION");
        }

        return (payFromToken, toTokenAmount, payVUSD);
    }

    // for pmmPricing
    function queryBuyBaseTokenForLib(PMMPricing.PMMState memory state, uint256 amount) public pure returns (uint256) {
        uint256 payQuote = PMMPricing._queryBuyBaseToken(state, amount);
        return payQuote;
    }
    
    // for dodo math
    function queryBuyBaseTokenForMath(PMMPricing.PMMState memory state, uint256 amount) public pure returns (uint256) {
        uint256 payQuote = _BuyBaseTokenForMath(state, amount, state.B, state.B0);
        return payQuote;
    }

    function _BuyBaseTokenForMath(
        PMMPricing.PMMState memory state,
        uint256 amount,
        uint256 baseBalance,
        uint256 targetBaseAmount
    ) public pure returns (uint256) {
        require(amount < baseBalance, "DODOstate.BNOT_ENOUGH");
        uint256 B2 = baseBalance - amount;

        uint256 payQuoteToken = DODOMath._GeneralIntegrate(targetBaseAmount, baseBalance, B2, state.i, state.K);
        return payQuoteToken;
    }

    // ================ querySell for lib ===================

}

contract PMMRangeOrderTest is TestContext {
    D3Maker public d3Maker;
    MockD3Pool public mockd3MM;
    PMMRangeOrderHelper public pmmRangeOrderHelper;
    

    function setUp() public {
        createTokens();
        createD3Oracle();
        mockd3MM = new MockD3Pool();
        d3Maker = new D3Maker();
        d3Maker.init(owner, address(mockd3MM), 100000);
        pmmRangeOrderHelper = new PMMRangeOrderHelper();

        // set token price
        MakerTypes.TokenMMInfoWithoutCum memory token1Info = contructToken1Dec8MMInfo();
        MakerTypes.TokenMMInfoWithoutCum memory token2Info = contructToken2MMInfo();
        MakerTypes.TokenMMInfoWithoutCum memory token3Info = contructToken3MMInfo();
        vm.startPrank(owner);
        d3Maker.setNewToken(address(token1), true, token1Info.priceInfo, token1Info.amountInfo, token1Info.kAsk, token1Info.kBid); // dec is 8
        d3Maker.setNewToken(address(token2), true, token2Info.priceInfo, token2Info.amountInfo, token2Info.kAsk, token2Info.kBid);
        d3Maker.setNewToken(address(token3), true, token3Info.priceInfo, token3Info.amountInfo, token3Info.kAsk, token3Info.kBid);
        vm.stopPrank();
    }

    function get12RangeOrder() public view returns(Types.RangeOrderState memory roState) {
        roState.oracle = address(oracle);

        (roState.fromTokenMMInfo, ) = d3Maker.getTokenMMInfoForPool(address(token1)); //1300
        roState.fromTokenMMInfo.cumulativeAsk = roState.fromTokenMMInfo.cumulativeBid = 0;

        (roState.toTokenMMInfo, ) = d3Maker.getTokenMMInfoForPool(address(token2)); // 12
        roState.toTokenMMInfo.cumulativeAsk = roState.toTokenMMInfo.cumulativeBid = 0;
    }

    function testQuerySellTokens() public {
        Types.RangeOrderState memory roState = get12RangeOrder();
        // fromToken is 1300, toToken is 12

        (uint256 fromAmount, uint256 receiveToToken, uint256 vusdAmount) = pmmRangeOrderHelper.querySellTokens(roState, address(token1), address(token2), 10 ** 18);
        assertEq(fromAmount, 10**18);
        assertEq(receiveToToken, 24964525068078312916); // 24.96, because max vusdAmount = 300, suppose 25
        assertEq(vusdAmount, 300 * (10** 18));

        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.querySellTokens(roState, address(token1), address(token2), 10 ** 17);
        assertEq(fromAmount, 10**17);
        //console.log(receiveToToken);
        //console.log(vusdAmount);
        assertEq(receiveToToken, 10812649799795029422); // 10.81, suppose near 10.83
        assertEq(vusdAmount, 129890376538907193976); // 129.8, suppose near 130

        // with cumulative
        roState.fromTokenMMInfo.cumulativeAsk = 4 * (10 ** 18);
        roState.fromTokenMMInfo.cumulativeBid = 40 * (10 ** 18);
        roState.toTokenMMInfo.cumulativeBid = roState.toTokenMMInfo.cumulativeAsk = 4 * (10 ** 18);

        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.querySellTokens(roState, address(token1), address(token2), 10 ** 18);
        assertEq(fromAmount, 10**18);
        assertEq(receiveToToken, 21633407960311327528); // 21.63, because max vusdAmount = 260, suppose near 21.67
        assertEq(vusdAmount, 260 * (10** 18));

        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.querySellTokens(roState, address(token1), address(token2), 10 ** 17);
        assertEq(fromAmount, 10**17);
        assertEq(receiveToToken, 10810214517700684559); // 10.81, suppose near 10.83 < 10812
        assertEq(vusdAmount, 129886911976839434749); // 129.8, suppose near 130, < 12989

        // change fromToken and toToken, fromToken = 12, toToken = 1300
        Types.TokenMMInfo memory tokenMMInfo = roState.toTokenMMInfo;
        roState.toTokenMMInfo = roState.fromTokenMMInfo;
        roState.fromTokenMMInfo = tokenMMInfo;

        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.querySellTokens(roState, address(token2), address(token1), (100)*10 ** 18);
        assertEq(fromAmount, (100)*10 ** 18);
        assertEq(receiveToToken, 19982947988629054); // 0.019, suppose near 0.02
        assertEq(vusdAmount, 26 * (10** 18)); // suppose 1200, max vusdAmount = 26

        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.querySellTokens(roState, address(token2), address(token1), 10 ** 18);
        assertEq(fromAmount, 10 ** 18);
        assertEq(receiveToToken, 9213376791555881); // 0.0092, suppose near 0.00923
        assertEq(vusdAmount, 11987609614474078065); // 11.9, suppose 12, 
    }

    function testQueryBuyTokens() public {
        Types.RangeOrderState memory roState = get12RangeOrder();
        // fromToken is 1300, toToken is 12

        (uint256 fromAmount, uint256 receiveToToken, uint256 vusdAmount) = pmmRangeOrderHelper.queryBuyTokens(roState, address(token1), address(token2), 24964525068078312916);
        assertEq(fromAmount, 230977100923055001); // 0.2309, suppose near(>) 0.2304
        assertEq(receiveToToken, 24964525068078312916); // 24.96
        assertEq(vusdAmount, 299999999999999998460); // 299.99, suppose near 300
        //console.log(fromAmount);
        //console.log(vusdAmount);

        
        vm.expectRevert(bytes("PMMRO_VAULT_RESERVE_NOT_ENOUGH"));
        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.queryBuyTokens(roState, address(token1), address(token2),40 * (10 ** 18));
        
        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.queryBuyTokensLoc(roState, address(token1), address(token2), 10812725271096067414);
        assertEq(fromAmount, 100000698208426075); // suppose nead 1e18
        assertEq(receiveToToken, 10812725271096067414); // 0.01
        assertEq(vusdAmount, 129891283405183499173); // 12.9, suppose near 129891283405183499858

        // with cumulative
        roState.fromTokenMMInfo.cumulativeAsk = 4 * (10 ** 18);
        roState.fromTokenMMInfo.cumulativeBid = 40 * (10 ** 18);
        roState.toTokenMMInfo.cumulativeBid = roState.toTokenMMInfo.cumulativeAsk = 4 * (10 ** 18);

        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.queryBuyTokens(roState, address(token1), address(token2), 21633407960311327528);
        assertEq(fromAmount, 200182824626646523); // suppose near(>) 0.02
        assertEq(receiveToToken, 21633407960311327528); // 21.63, because max vusdAmount = 260, suppose near 21.67
        assertEq(vusdAmount, 259999999999999954026); // suppose 260

        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.queryBuyTokens(roState, address(token1), address(token2), 10810278971047276557);
        assertEq(fromAmount, 100000596412654143); // suppose 1e18
        assertEq(receiveToToken, 10810278971047276557); // 10.81, suppose near 10.83 < 10812
        assertEq(vusdAmount, 129887686605257200476); // suppose 129887686605257245795,  129.8

        // change fromToken and toToken, fromToken = 12, toToken = 1300
        Types.TokenMMInfo memory tokenMMInfo = roState.toTokenMMInfo;
        roState.toTokenMMInfo = roState.fromTokenMMInfo;
        roState.fromTokenMMInfo = tokenMMInfo;

        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.queryBuyTokens(roState, address(token2), address(token1), 19982947988629054);
        assertEq(fromAmount, 2169261355031671770); //21.6, suppose near(>) 21.6
        assertEq(receiveToToken, 19982947988629054); // 0.019, suppose near 0.02
        assertEq(vusdAmount, 25999999999989768292); //suppose near 26 * (10** 18)), max vusdAmount = 26

        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.queryBuyTokens(roState, address(token2), address(token1), 9213376791555881);
        assertEq(fromAmount, 999999999999146822); // suppose 1e18
        assertEq(receiveToToken, 9213376791555881); // 0.0092, suppose near 0.00923
        assertEq(vusdAmount, 11987609614463856804); // suppose 11987609614474078065,  11.9
    }

    function testKisZero() public {
        Types.RangeOrderState memory roState = get12RangeOrder();
        // fromToken is 1300, toToken is 12
        
        (uint256 fromAmount, uint256 receiveToToken, uint256 vusdAmount) = pmmRangeOrderHelper.queryBuyTokens(roState, address(token1), address(token2), 1e19);
        assertEq(fromAmount, 92482101050675776); 
        assertEq(receiveToToken, 1e19); // 10
        assertEq(vusdAmount, 120125740394024407940);
        //console.log(fromAmount);
        //console.log(vusdAmount);

        roState.fromTokenMMInfo.kBid = 0;
        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.queryBuyTokens(roState, address(token1), address(token2), 1e19);
        assertEq(fromAmount, 92478398406436275); 
        assertEq(receiveToToken, 1e19); // 10
        assertEq(vusdAmount, 120125740394024407940);
    }

    function testPriceIsZero() public {
        Types.RangeOrderState memory roState = get12RangeOrder();
        // fromToken is 1300, toToken is 12
        roState.fromTokenMMInfo.bidDownPrice = 0;
        
        vm.expectRevert(bytes("PMMRO_PRICE_ZERO"));
        pmmRangeOrderHelper.queryBuyTokens(roState, address(token1), address(token2), 1e19);
    }

    function testAmountIsZero() public {
        Types.RangeOrderState memory roState = get12RangeOrder();
        // fromToken is 1300, toToken is 12
        roState.fromTokenMMInfo.bidAmount = 0;
        
        vm.expectRevert(bytes("PMMRO_AMOUNT_ZERO"));
        pmmRangeOrderHelper.queryBuyTokens(roState, address(token1), address(token2), 1e19);
    }

    function testOracleProtection() public {
        
        Types.RangeOrderState memory roState = get12RangeOrder();
        // fromToken is 1300, toToken is 12
        token2ChainLinkOracle.feedData(13000 * 1e18);
        vm.expectRevert(bytes("PMMRO_ORACLE_PRICE_PROTECTION"));
        (uint256 fromAmount, uint256 receiveToToken, uint256 vusdAmount) = pmmRangeOrderHelper.queryBuyTokens(roState, address(token1), address(token2), 1e19);
        token2ChainLinkOracle.feedData(12* 1e18);

        token1ChainLinkOracle.feedData(13 * 1e18);
        vm.expectRevert(bytes("PMMRO_ORACLE_PRICE_PROTECTION"));
        (fromAmount, receiveToToken, vusdAmount) = pmmRangeOrderHelper.querySellTokens(roState, address(token1), address(token2), 1e8);
        
    }
}