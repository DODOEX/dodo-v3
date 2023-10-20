/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";
import "contracts/DODOV3MM/lib/MakerTypes.sol";

contract MakerTypesHelper {
    function parseAskAmount(uint64 amountInfo) external pure returns(uint256) {
       uint256 askAmount =  MakerTypes.parseAskAmount(amountInfo);
       return askAmount;
    }

    function parseBidAmount(uint64 amountInfo) external pure returns(uint256) {
        uint256 bidAmount = MakerTypes.parseBidAmount(amountInfo);
        return bidAmount;
    }

    function parseAllPrice(uint80 priceInfo)
        external
        pure
        returns (uint256 , uint256 , uint256 , uint256 , uint256)
    {
        (uint256 askUpPrice, uint256 askDownPrice, uint256 bidUpPrice, uint256 bidDownPrice, uint256 swapFee) =  MakerTypes.parseAllPrice(priceInfo);
        return (askUpPrice, askDownPrice,  bidUpPrice, bidDownPrice, swapFee);
    }

    function parseK(uint16 originK) external pure returns (uint256) {
        uint256 k = MakerTypes.parseK(originK);
        return k;
    }
}

contract MakerTypeTest is TestContext {
    MakerTypesHelper public makerTypes;

    function setUp() public {
        makerTypes = new MakerTypesHelper();
    }

    function testParseAskAmount() public {
        uint64 amountSet = stickAmount(30, 18, 30, 18);
        uint256 askAmount = makerTypes.parseAskAmount(amountSet);
        assertEq(askAmount, 30 * (10 ** 18));
    }

    function testParseBidAmount() public {
        uint64 amountSet = stickAmount(30, 18, 30, 8);
        uint256 bidAmount = makerTypes.parseBidAmount(amountSet);
        assertEq(bidAmount, 30 * (10 ** 8));
    }

    function testParseK() public {
        uint256 k = makerTypes.parseK(uint16(1000));
        assertEq(k, 10 ** 17);
    }

    function testParseAllPrice() public {
        uint80 priceInfo = stickPrice(27880, 18, 6, 12, 10);
        (uint256 askUpPrice, uint256 askDownPrice, uint256 bidUpPrice, uint256 bidDownPrice, uint256 swapFee) = makerTypes.parseAllPrice(priceInfo); //0.02%
        assertEq(askUpPrice, 27913456 * (10 ** 15)); // 27913.456
        assertEq(askDownPrice, 27896728 * (10 ** 15)); // 27896.728
        assertEq(bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
        assertEq(bidDownPrice, 35889539462559); // 1/27863.272, 27880 - 27880 * 0.06% = 27863.272
        assertEq(swapFee, 6 * (10 ** 14)); //0.06%

        (askUpPrice, askDownPrice, bidUpPrice, bidDownPrice, swapFee) = makerTypes.parseAllPrice(priceInfo);
        assertEq(askUpPrice, 27913456 * (10 ** 15)); //decimal is still 18
        assertEq(askDownPrice, 27896728 * (10 ** 15)); // decimal is still 18
        assertEq(bidUpPrice, 35903909648530); //  decimal is 18, 0.00003590
        assertEq(bidDownPrice, 35889539462559); // decimal is 18
        assertEq(swapFee, 6 * (10 ** 14));
    }

    function testParseAllPriceWithZeroFeeRate() public {
        uint80 priceInfo = stickPrice(27880, 18, 0, 12, 10);
        (uint256 askUpPrice, uint256 askDownPrice, uint256 bidUpPrice, uint256 bidDownPrice, uint256 swapFee) = makerTypes.parseAllPrice(priceInfo); //0.02%
        assertEq(askUpPrice, 27913456 * (10 ** 15)); // 27913.456
        assertEq(askDownPrice, 27880 * (10 ** 18)); // 27896.728
        assertEq(bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
        assertEq(bidDownPrice, 35868005738881); // 1/27880
        assertEq(swapFee, 0); //0.06%
    }

    function testPriceInvalid() public {
        uint80 priceInfo = stickPrice(27880, 18, 13, 12, 14);
        vm.expectRevert(bytes("ask price invalid"));
        (uint256 askUpPrice, uint256 askDownPrice, uint256 bidUpPrice, uint256 bidDownPrice, uint256 swapFee) = makerTypes.parseAllPrice(priceInfo);

        priceInfo = stickPrice(27880, 18, 11, 12, 10);
        vm.expectRevert(bytes("bid price invalid"));
        (askUpPrice, askDownPrice, bidUpPrice, bidDownPrice, swapFee) = makerTypes.parseAllPrice(priceInfo);
    }

}