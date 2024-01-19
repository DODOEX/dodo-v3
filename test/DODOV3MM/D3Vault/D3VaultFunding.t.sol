/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../../TestContext.t.sol";

contract D3VaultFundingTest is TestContext {
    function setUp() public {
        contextBasic();
        token1.mint(user1, 1000 * 1e8);
        token1.mint(user2, 1000 * 1e8);
        vm.prank(user1);
        token1.approve(address(d3Vault), type(uint256).max);
        vm.prank(user2);
        token1.approve(address(d3Vault), type(uint256).max);
    }

    function testInit() public {
        assertEq(d3Vault.owner(), vaultOwner);
    }

    function testUserDeposit() public {
        (address dToken1,,,,,,,,,,) = d3Vault.getAssetInfo(address(token1));
        vm.prank(user1);
        token1.approve(address(dodoApprove), type(uint256).max);
        vm.prank(user2);
        token1.approve(address(dodoApprove), type(uint256).max);

        // case 0: fail - minimum amount required for the first deposit
        mockUserQuota.setUserQuota(user1, address(token1), 2000);
        vm.prank(user1);
        vm.expectRevert(Errors.D3VaultMinimumDToken.selector);
        d3Proxy.userDeposit(user1, address(token1), DEFAULT_MINIMUM_DTOKEN - 1, 0);

        // case 1: fail - exceed quota
        vm.prank(user1);
        vm.expectRevert(Errors.D3VaultExceedQuota.selector);
        d3Proxy.userDeposit(user1, address(token1), 500 * 1e8, 0);

        // case 2: success
        mockUserQuota.setUserQuota(user1, address(token1), 1000 * 1e8);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token1), 500 * 1e8, 0);
        assertEq(D3Token(dToken1).balanceOf(user1), 500 * 1e8 - DEFAULT_MINIMUM_DTOKEN); // 1000 dToken is locked to address(1)
        
        // case 3: exceed max deposit
        mockUserQuota.setUserQuota(user2, address(token1), 1000 * 1e8);
        assertEq(token1.balanceOf(user2), 1000 * 1e8);
        vm.prank(user2);
        d3Proxy.userDeposit(user2, address(token1), 500 * 1e8, 0);
        assertEq(token1.balanceOf(user2), 500 * 1e8);

        vm.prank(user2);
        vm.expectRevert(Errors.D3VaultExceedMaxDepositAmount.selector);
        d3Proxy.userDeposit(user2, address(token1), 1, 0);
        assertEq(token1.balanceOf(user2), 500 * 1e8);
    }

    function testUserWithdraw() public {
        vm.prank(user1);
        token1.approve(address(dodoApprove), type(uint256).max);

        mockUserQuota.setUserQuota(user1, address(token1), 1000 * 1e8);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token1), 100 * 1e8, 0);
        
        uint256 balance1 = token1.balanceOf(user1);
        userWithdraw(user1, address(token1), 100 * 1e8 - DEFAULT_MINIMUM_DTOKEN);
        uint256 balance2 = token1.balanceOf(user1);
        assertEq(balance2 - balance1, 100 * 1e8 - DEFAULT_MINIMUM_DTOKEN);

        // case: withdraw amount larger than dToken balance
        vm.expectRevert(Errors.D3VaultDTokenBalanceNotEnough.selector);
        userWithdraw(user1, address(token1), 100 * 1e8);
    }

    function testPoolBorrow() public {
        vm.prank(user1);
        token1.approve(address(dodoApprove), type(uint256).max);

        mockUserQuota.setUserQuota(user1, address(token1), 1000 * 1e8);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token1), 500 * 1e8, 0);

        // case 1: has no collateral
        // after borrow, pooh has
        // balance: 100 token1
        // borrowed: 100 token1
        // net positive: balance - borrowed = 100 - 100 = 0
        // collateral ratio = 0 < 1 + IM
        vm.expectRevert(bytes(PoolErrors.NOT_SAFE));
        poolBorrow(address(d3MM), address(token1), 100 * 1e8);

        // case 2: has collateral, borrow 100 token1
        // now pool has
        // balance: 200 token1
        // borrowed: 100 token1
        // token1's max collateral amount is 100, 
        // only 100 token1 can be used as collateral
        // collateralRatioBorrow = 100 / 100 = 100% > IM
        token1.mint(address(d3MM), 100 * 1e8);
        d3MM.updateReserve(address(token1));
        // case 2.1: borrow exceed pool quota
        poolQuota.enableQuota(address(token1), true);
        address[] memory addressList = new address[](1);
        uint256[] memory quotaList = new uint256[](1);
        addressList[0] = address(d3MM);
        quotaList[0] = 1;
        poolQuota.setPoolQuota(address(token1), addressList, quotaList);
        vm.expectRevert(Errors.D3VaultExceedQuota.selector);
        poolBorrow(address(d3MM), address(token1), 100 * 1e8);
        // case 2.2: borrow not exceed pool quota
        quotaList[0] = 1000 * 1e8;
        poolQuota.setPoolQuota(address(token1), addressList, quotaList);
        poolBorrow(address(d3MM), address(token1), 100 * 1e8);

        uint256 leftQuota = d3Vault.getPoolLeftQuota(address(d3MM), address(token1));
        assertEq(leftQuota, 900 * 1e8);

        // case 3: has collateral, borrow too much, borrow 300 token1
        // now pool has
        // balance: 400 token1
        // borrowed: 300 token1
        // min(maxCollateralAmount, balance - borrowed) = 100
        // collateralRatioBorrow = 100 / 300 = 33% < IM
        vm.expectRevert(bytes(PoolErrors.NOT_BORROW_SAFE));
        poolBorrow(address(d3MM), address(token1), 200 * 1e8);

        // case 4: pool borrow asset which is not the collateral token
        vm.expectRevert(Errors.D3VaultAmountExceedVaultBalance.selector);
        poolBorrow(address(d3MM), address(token2), 1 ether); 

        vm.prank(user1);
        token2.approve(address(dodoApprove), type(uint256).max);
        token2.mint(user1, 1000 ether);
        mockUserQuota.setUserQuota(user1, address(token2), 1000 ether);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token2), 500 ether, 0);
        
        poolBorrow(address(d3MM), address(token2), 10 ether);
        token2.burn(address(d3MM), 1 ether);
        d3MM.updateReserve(address(token2));
        // pool has 200 token1, 9 token2
        // borrowed 100 token1, 10 token2
        poolBorrow(address(d3MM), address(token2), 1 ether);
        // pool has 200 token1, 10 token2
        // borrowed 100 token1, 11 token2
        (uint256 token2Balance, uint256 token2Borrowed) = d3Vault.getBalanceAndBorrows(address(d3MM), address(token2));
        assertEq(token2Balance, 10 ether);
        assertEq(token2Borrowed, 11 ether);

        vm.warp(3150);
        leftQuota = d3Vault.getPoolLeftQuota(address(d3MM), address(token1));
        assertEq(leftQuota, 89999600576);

        // borrow after some time
        poolBorrow(address(d3MM), address(token1), 10);
        leftQuota = d3Vault.getPoolLeftQuota(address(d3MM), address(token1));
        assertEq(leftQuota, 89999600566);
    }

    function testPoolRepay() public {
        vm.prank(user1);
        token1.approve(address(dodoApprove), type(uint256).max);

        mockUserQuota.setUserQuota(user1, address(token1), 1000 * 1e8);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token1), 500 * 1e8, 0);

        token1.mint(address(d3MM), 100 * 1e8);
        poolBorrow(address(d3MM), address(token1), 100 * 1e8);

        // user1 deposit 500 into vault
        // pool has 100 as collateral, then borrow 100
        // utilization ratio = borrow / (cash + borrows) = 100 / 500 = 20%
        // borrowRate = 20% + 1 * 20% = 40%
        uint256 totalBorrows = d3Vault.getTotalBorrows(address(token1));
        assertEq(totalBorrows, 100 * 1e8);
        uint256 utilizationRatio = d3Vault.getUtilizationRatio(address(token1));
        assertEq(utilizationRatio, 20 * 1e16);
        uint256 borrowRate = d3Vault.getBorrowRate(address(token1));
        assertEq(borrowRate, 40 * 1e16);

        // pass one year
        vm.warp(31536000 + 1);

        // after one year, the compound interst is (1 + 0.4/31536000)^31536000 = 1.491824694
        uint256 compoundInterestRate = d3Vault.getCompoundInterestRate(borrowRate / 31536000, 31536000);
        assertEq(compoundInterestRate, 1479561541141168000);

        vm.startPrank(address(d3MM));
        uint256 newBorrows = d3Vault.getPoolBorrowAmount(address(d3MM), address(token1));
        assertEq(newBorrows, 14795615411);

        token1.approve(address(d3Vault), type(uint256).max);
        d3Vault.poolRepay(address(token1), 100 * 1e8);
        
        uint256 newBorrows2 = d3Vault.getPoolBorrowAmount(address(d3MM), address(token1));
        assertEq(newBorrows2, 4795615411);

        // case: repay more than borrows
        vm.expectRevert(Errors.D3VaultAmountExceed.selector);
        d3Vault.poolRepay(address(token1), 4795615411 + 1);

        (,,,,,,,,,, uint256 balanceBefore) = d3Vault.getAssetInfo(address(token1));
        (, uint256 totalBorrowsBefore,,,,,,,,,) = d3Vault.getAssetInfo(address(token1));
        d3Vault.poolRepayAll(address(token1));
        (,,,,,,,,,, uint256 balanceAfter) = d3Vault.getAssetInfo(address(token1));
        (, uint256 totalBorrowsAfter,,,,,,,,,) = d3Vault.getAssetInfo(address(token1));
        uint256 newBorrows3 = d3Vault.getPoolBorrowAmount(address(d3MM), address(token1));
        assertEq(newBorrows3, 0);
        assertEq(balanceAfter - balanceBefore, totalBorrowsBefore - totalBorrowsAfter);
        
        vm.stopPrank();
    }

    function testCompoundInterestRate() public {
        assertEq(d3Vault.getCompoundInterestRate(3e18, 0), 1e18);
        assertEq(d3Vault.getCompoundInterestRate(3e18, 1), 4e18);
        assertEq(d3Vault.getCompoundInterestRate(3e18, 2), 1e18 + 6e18 + 9e18);
        assertEq(d3Vault.getCompoundInterestRate(3e18, 3), 1e18 + 9e18 + 27e18);
    }

    function testBorrowWhenVaultOnlyHasReserves() public {
        // user1 deposit 10 into vault
        // pool has 100 as collateral, then borrow 10
        // after 10s, pools repay all.
        // user1 with 10 from vault
        // pool tries to borrow 1 wei.
        vm.prank(user1);
        token1.approve(address(dodoApprove), type(uint256).max);

        mockUserQuota.setUserQuota(user1, address(token1), 1000 * 1e8);
        vm.prank(user1);
        d3Proxy.userDeposit(user1, address(token1), 10 * 1e8, 0);

        token1.mint(address(d3MM), 100 * 1e8);
        poolBorrow(address(d3MM), address(token1), 10 * 1e8);

        // pass 10s
        vm.warp(10 + 1);

        vm.startPrank(address(d3MM));

        token1.approve(address(d3Vault), type(uint256).max);

        d3Vault.accrueInterest(address(token1));
        uint256 repayAmount = d3Vault.getTotalBorrows(address(token1));

        d3Vault.poolRepay(address(token1), repayAmount);
        assertEq(d3Vault.getTotalBorrows(address(token1)), 0);

        vm.stopPrank();

        userWithdraw(user1, address(token1), 10 * 1e8 - DEFAULT_MINIMUM_DTOKEN);
        userWithdraw(address(1), address(token1), DEFAULT_MINIMUM_DTOKEN);

        vm.expectRevert(Errors.D3VaultAmountExceedVaultBalance.selector);
        poolBorrow(address(d3MM), address(token1), 1);
        uint256 getURatio = d3Vault.getUtilizationRatio(address(token1));
        assertEq(getURatio, 0);
    }
}
