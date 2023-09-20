/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";
import "contracts/DODOV3MM/lib/Types.sol";

contract TypesHelper {
    function parseRealAmount(uint256 realAmount, uint256 tokenDec) external pure returns(uint256) {
       uint256 dec18Amount =  Types.parseRealAmount(realAmount, tokenDec);
       return dec18Amount;
    }

    function parseDec18Amount(uint256 amountWithDec18, uint256 tokenDec) external pure returns(uint256) {
        uint256 realAmount = Types.parseDec18Amount(amountWithDec18, tokenDec);
        return realAmount;
    }
}

contract TypesTest is Test {
    TypesHelper public typesHelper;

    function setUp() public {
        typesHelper = new TypesHelper();
    }

    function testParseRealAmount() public {
        uint256 dec18Amount = typesHelper.parseRealAmount(12 * 1e18, 18);
        assertEq(dec18Amount, 12 * 1e18);
        dec18Amount = typesHelper.parseRealAmount(12 * 1e18, 24);
        assertEq(dec18Amount, 12 * 1e12);
        dec18Amount = typesHelper.parseRealAmount(12 * 1e18, 12);
        assertEq(dec18Amount, 12 * 1e24);
    }

    function testParseDec18Amount() public {
        uint256 realAmount = typesHelper.parseDec18Amount(12 * 1e18, 18);
        assertEq(realAmount, 12 * 1e18);
        realAmount = typesHelper.parseDec18Amount(12 * 1e18, 8);
        assertEq(realAmount, 12 * 1e8);
        realAmount = typesHelper.parseDec18Amount(12 * 1e18, 24);
        assertEq(realAmount, 12 * 1e24);
    }
}