// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "contracts/DODOV3MM/lib/DecimalMath.sol";

// This helper contract exposes internal library functions for coverage to pick up
// check this link: https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086
contract DecimalMathTestHelper {

    function mul(uint256 target, uint256 d) external pure returns (uint256) {
        // this line may seem redundant, just to make forge coverage to cover
        uint256 result = DecimalMath.mul(target, d);
        return result;
    }

    function mulFloor(uint256 target, uint256 d) external pure returns (uint256) {
        uint256 result = DecimalMath.mulFloor(target, d);
        return result;
    } 

    function mulCeil(uint256 target, uint256 d) external pure returns (uint256) {
        uint256 result = DecimalMath.mulCeil(target, d);
        return result;
    }

    function div(uint256 target, uint256 d) external pure returns (uint256) {
        uint256 result = DecimalMath.div(target, d);
        return result;
    }

    function divFloor(uint256 target, uint256 d) external pure returns (uint256) {
        uint256 result = DecimalMath.divFloor(target, d);
        return result;
    }

    function divCeil(uint256 target, uint256 d) external pure returns (uint256) {
        uint256 result = DecimalMath.divCeil(target, d);
        return result;
    }

    function reciprocalFloor(uint256 target) external pure returns (uint256) {
        uint256 result = DecimalMath.reciprocalFloor(target);
        return result;
    }

    function reciprocalCeil(uint256 target) external pure returns (uint256) {
        uint256 result = DecimalMath.reciprocalCeil(target);
        return result;
    }

    function sqrt(uint256 target) external pure returns (uint256) {
        uint256 result = DecimalMath.sqrt(target); 
        return result;
    }

    function powFloor(uint256 target, uint256 e) external pure returns (uint256) {
        uint256 result = DecimalMath.powFloor(target, e);
        return result;
    }

    function _divCeil(uint256 a, uint256 b) external pure returns (uint256) {
        uint256 result = DecimalMath._divCeil(a, b);
        return result;
    }
}

contract DecimalMathTest is Test {
    DecimalMathTestHelper public helper;

    function setUp() public {
        helper = new DecimalMathTestHelper();
    }

    function testMul() public {
        assertEq(helper.mul(1, 1e18), 1);
        assertEq(helper.mul(2, 2e18), 4);
        assertEq(helper.mul(2, 2), 0);
    }

    function testMulFloor() public {
        assertEq(helper.mulFloor(1, 1), 0);
        assertEq(helper.mulFloor(1e18, 1e18), 1e18);
    }

    function testMulCeil() public {
        assertEq(helper.mulCeil(1, 1), 1);
        assertEq(helper.mulCeil(1, 2), 1);
        assertEq(helper.mulCeil(1, 1e18), 1);
    }

    function testDiv() public {
        assertEq(helper.div(1, 1e18), 1);
    }

    function testDivZero() public {
        vm.expectRevert();
        helper.div(1, 0);
    }

    function testDivFloor() public {
        assertEq(helper.divFloor(1, 1e18), 1);
        assertEq(helper.divFloor(1, 2e18), 0);
    }

    function testDivCeil() public {
        assertEq(helper.divCeil(1, 1e18), 1);
        assertEq(helper.divCeil(1, 1), 1e18);
        assertEq(helper.divCeil(1, 2e18), 1);
    }

    function testReciprocalFloor() public {
        assertEq(helper.reciprocalFloor(1e18), 1e18);
        assertEq(helper.reciprocalFloor(2e18), 5e17);
        assertEq(helper.reciprocalFloor(1), 1e36);
        assertEq(helper.reciprocalFloor(1e36), 1);
        assertEq(helper.reciprocalFloor(1e37), 0);
    }

    function testReciprocalCeil() public {
        assertEq(helper.reciprocalCeil(1e18), 1e18);
        assertEq(helper.reciprocalCeil(2e18), 5e17);
        assertEq(helper.reciprocalCeil(1), 1e36);
        assertEq(helper.reciprocalCeil(1e36), 1);
        assertEq(helper.reciprocalCeil(1e37), 1);
    }

    function testSqrt() public {
        assertEq(helper.sqrt(1e18), 1e18);
    }

    function testPowFloor() public {
        assertEq(helper.powFloor(3e18, 0), 1e18);
        assertEq(helper.powFloor(1e18, 2), 1e18);
        assertEq(helper.powFloor(2e18, 3), 8e18);
    }

    function testNonDecimalDivCeil() public {
        assertEq(helper._divCeil(4, 3), 2);
        assertEq(helper._divCeil(5, 3), 2);
        assertEq(helper._divCeil(6, 3), 2);
        assertEq(helper._divCeil(7, 3), 3);
    }
}