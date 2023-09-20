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

    function parseAllPrice(uint80 priceInfo, uint256 tokenDecimal, uint256 mtFeeRate)
        external
        pure
        returns (uint256 , uint256 , uint256 , uint256 , uint256)
    {
        (uint256 askUpPrice, uint256 askDownPrice, uint256 bidUpPrice, uint256 bidDownPrice, uint256 swapFee) =  MakerTypes.parseAllPrice(priceInfo, mtFeeRate);
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
        (uint256 askUpPrice, uint256 askDownPrice, uint256 bidUpPrice, uint256 bidDownPrice, uint256 swapFee) = makerTypes.parseAllPrice(priceInfo, 18, (2*10**14)); //0.02%
        assertEq(askUpPrice, 27913456 * (10 ** 15)); // 27913.456
        assertEq(askDownPrice, 27902304 * (10 ** 15)); // 27902.304
        assertEq(bidUpPrice, 35903909648530); // 1/27852.12, 27880 - 27880 * 0.1% =27852.12
        assertEq(bidDownPrice, 35896723117375); // 1/27857.696, 27880 - 27880 * 0.08% = 27867.696
        assertEq(swapFee, 8 * (10 ** 14)); //0.08%

        (askUpPrice, askDownPrice, bidUpPrice, bidDownPrice, swapFee) = makerTypes.parseAllPrice(priceInfo, 8, (2*10**14));
        assertEq(askUpPrice, 27913456 * (10 ** 15)); //decimal is still 18
        assertEq(askDownPrice, 27902304 * (10 ** 15)); // decimal is still 18
        assertEq(bidUpPrice, 35903909648530); //  decimal is 18, 0.00003590
        assertEq(bidDownPrice, 35896723117375); // decimal is 18
        assertEq(swapFee, 8 * (10 ** 14));
    }

    function testPriceInvalid() public {
        uint80 priceInfo = stickPrice(27880, 18, 6, 12, 10);
        vm.expectRevert(bytes("ask price invalid"));
        (uint256 askUpPrice, uint256 askDownPrice, uint256 bidUpPrice, uint256 bidDownPrice, uint256 swapFee) = makerTypes.parseAllPrice(priceInfo, 18, 10**15);

        vm.expectRevert(bytes("bid price invalid"));
        (askUpPrice, askDownPrice, bidUpPrice, bidDownPrice, swapFee) = makerTypes.parseAllPrice(priceInfo, 8, (5*10**14));
    }

}