// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "contracts/DODOV3MM/lib/DODOMath.sol";

// This helper contract exposes internal library functions for coverage to pick up
// check this link: https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086
contract DODOMathTestHelper {
    function _GeneralIntegrate(
        uint256 V0,
        uint256 V1,
        uint256 V2,
        uint256 i,
        uint256 k
    ) external pure returns (uint256) {
        // this line may seem redundant, just to make forge coverage to cover
        uint256 result = DODOMath._GeneralIntegrate(V0, V1, V2, i, k);
        return result;
    }

    function _SolveQuadraticFunctionForTrade(
        uint256 V0,
        uint256 V1,
        uint256 delta,
        uint256 i,
        uint256 k
    ) external pure returns (uint256) {
        uint256 result = DODOMath._SolveQuadraticFunctionForTrade(V0, V1, delta, i, k);
        return result;
    }
}

contract DODOMathTest is Test {
    DODOMathTestHelper public helper;

    function setUp() public {
        helper = new DODOMathTestHelper();
    }

    function testGeneralIntegrate() public {
        assertEq(helper._GeneralIntegrate(120 ether, 100 ether, 50 ether, 10000, 1e16), 509400);
        assertEq(helper._GeneralIntegrate(120 ether, 100 ether, 50 ether, 10000, 0), 500000);
        assertEq(helper._GeneralIntegrate(120 ether, 100 ether, 50 ether, 10000, 1e18), 1440000);
        vm.expectRevert(bytes("TARGET_IS_ZERO"));
        helper._GeneralIntegrate(0, 100 ether, 50 ether, 10000, 1e18);
    }

    function testSolveQuadraticFunctionForTrade() public {
        // if V0 = 0
        vm.expectRevert(bytes("TARGET_IS_ZERO"));
        helper._SolveQuadraticFunctionForTrade(0, 100 ether, 40 ether, 1 ether, 0);

        // if deltaQ = 0
        assertEq(helper._SolveQuadraticFunctionForTrade(120 ether, 100 ether, 0, 1 ether, 0), 0);
        assertEq(helper._SolveQuadraticFunctionForTrade(120 ether, 100 ether, 1 ether, 0, 1e18), 0);
 
        // k = 0, constant price
        // Q0 = 120 ether, Q1 = 100 ether, deltaB = 40 ether, i = 1 ether;
        assertEq(helper._SolveQuadraticFunctionForTrade(120 ether, 100 ether, 40 ether, 1 ether, 0), 40 ether);
        // Q0 = 120 ether, Q1 = 100 ether, deltaB = 40 ether, i = 2 ether;
        assertEq(helper._SolveQuadraticFunctionForTrade(120 ether, 100 ether, 40 ether, 2 ether, 0), 80 ether);
        // Q0 = 120 ether, Q1 = 100 ether, deltaB = 140 ether, i = 1 ether; maximum return is Q1
        assertEq(helper._SolveQuadraticFunctionForTrade(120 ether, 100 ether, 140 ether, 1 ether, 0), 100 ether);
         // Q0 = 120 ether, Q1 = 100 ether, deltaB = 60 ether, i = 2 ether; maximum return is Q1
        assertEq(helper._SolveQuadraticFunctionForTrade(120 ether, 100 ether, 60 ether, 2 ether, 0), 100 ether);

        // k = 1 branch case
        assertEq(helper._SolveQuadraticFunctionForTrade(120 ether, 100 ether, 40 ether, 0, 1), 0);

        //normal case
        uint256 res = helper._SolveQuadraticFunctionForTrade(120 ether, 100 ether, 40 ether, 1, 1e17);
        assertEq(res, 38);
    }
}