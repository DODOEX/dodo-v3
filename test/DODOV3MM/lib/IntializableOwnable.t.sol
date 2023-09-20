// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "contracts/DODOV3MM/lib/InitializableOwnable.sol";

contract InitializableOwnableTest is Test {
    InitializableOwnable public ownable;

    address public user1 = address(1);
    address public user2 = address(2);
  
    function setUp() public {
      vm.label(user1, "user1");
      vm.label(user2, "user2");
      ownable = new InitializableOwnable();
    }

    function testInitOwner() public {
      ownable.initOwner(user1);
      assertEq(ownable._OWNER_(), user1);
    }

    function testTransferOwnership() public {
      ownable.initOwner(user1);
      vm.prank(user1);
      ownable.transferOwnership(user2);
      assertEq(ownable._NEW_OWNER_(), user2);
    }

    function testClaimOwnership() public {
      ownable.initOwner(user1);
      vm.prank(user1);
      ownable.transferOwnership(user2); 
      vm.prank(user2);
      ownable.claimOwnership();
      assertEq(ownable._OWNER_(), user2);
      assertEq(ownable._NEW_OWNER_(), address(0));
    }

    function testClaimOwnershipByNotNewOwner() public {
      ownable.initOwner(user1);
      vm.prank(user1);
      ownable.transferOwnership(user2); 
      vm.prank(user1);
      vm.expectRevert(bytes("INVALID_CLAIM"));
      ownable.claimOwnership();
    }
}