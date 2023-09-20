/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.16;

import "../../../TestContext.t.sol";

contract D3UserQuotaTest is TestContext {

    using DecimalMath for uint256;

    function setUp() public {
        createTokens();
        createD3Oracle();
        createD3VaultTwo();
        createD3Proxy();
    }

    function testEnableQuota() public {
        d3UserQuota.enableQuota(address(token1), false);
        uint256 userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, type(uint256).max);
    }

    function testEnableGlobalQuota() public {
        d3UserQuota.enableQuota(address(token1), true);
        d3UserQuota.enableGlobalQuota(address(token1), true);
        d3UserQuota.setGlobalQuota(address(token1), uint256(1300));
        uint256 userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 1300);
    }

    function testQuotaTokenHold() public {
        d3UserQuota.enableQuota(address(token1), true);
        d3UserQuota.enableGlobalQuota(address(token1), false);
        d3UserQuota.setVToken(address(dodo));
        uint256[] memory _tiers = new uint256[](3);
        _tiers[0] = 100 * 1e18;
        _tiers[1] = 1000 * 1e18;
        _tiers[2] = 10000 * 1e18;
        uint256[] memory _amounts = new uint256[](3);
        _amounts[0] = 100;
        _amounts[1] = 1000;
        _amounts[2] = 10000;
        d3UserQuota.setTiers(address(token1), _tiers, _amounts);
        uint256 userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 100);

        faucetToken(address(dodo), user1, 10 * 1e18);
        userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 100);

        faucetToken(address(dodo), user1, 200 * 1e18);
        // uint256 dodoBalance = MockERC20(address(dodo)).balanceOf(user1);
        // console2.log("dodo balance ",dodoBalance);
        userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 1000);

        faucetToken(address(dodo), user1, 1000 * 1e18);
        userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 10000);

        faucetToken(address(dodo), user1, 10000 * 1e18);
        userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 10000);  
    }

    function testQuotaTokenHoldTwo() public {
        vm.prank(user1);
        token1.approve(address(dodoApprove), type(uint256).max);
        d3UserQuota.enableQuota(address(token1), true);
        d3UserQuota.enableGlobalQuota(address(token1), false);
        d3UserQuota.setVToken(address(dodo));
        uint256[] memory _tiers = new uint256[](3);
        _tiers[0] = 100 * 1e18;
        _tiers[1] = 1000 * 1e18;
        _tiers[2] = 10000 * 1e18;
        uint256[] memory _amounts = new uint256[](3);
        _amounts[0] = 100;
        _amounts[1] = 1000;
        _amounts[2] = 10000;
        d3UserQuota.setTiers(address(token1), _tiers, _amounts);
        faucetToken(address(token1), user1, 1000 * 1e8);
        userDeposit(user1,address(token1), 5);
        uint256 userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 100 - 5);

        faucetToken(address(dodo), user1, 10 * 1e18);
        userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 100 - 5);

        faucetToken(address(dodo), user1, 200 * 1e18);
        userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 1000 - 5);

        faucetToken(address(dodo), user1, 1000 * 1e18);
        userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 10000 - 5);

        faucetToken(address(dodo), user1, 10000 * 1e18);
        userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 10000 - 5);

        faucetToken(address(dodo), user1, 20000 * 1e18);
        userQuota = d3UserQuota.getUserQuota(user1, address(token1));
        assertEq(userQuota, 10000 - 5);
    }

    function testCheckQuota() public {
        d3UserQuota.enableQuota(address(token1), true);
        d3UserQuota.enableGlobalQuota(address(token1), false);
         d3UserQuota.setVToken(address(dodo));
        uint256[] memory _tiers = new uint256[](3);
        _tiers[0] = 100 * 1e18;
        _tiers[1] = 1000 * 1e18;
        _tiers[2] = 10000 * 1e18;
        uint256[] memory _amounts = new uint256[](3);
        _amounts[0] = 100;
        _amounts[1] = 1000;
        _amounts[2] = 10000;
        d3UserQuota.setTiers(address(token1), _tiers, _amounts);
        bool check = d3UserQuota.checkQuota(user1, address(token1), 100);
        assertEq(check, true);
        check = d3UserQuota.checkQuota(user1, address(token1), 100 + 1);
        assertEq(check, false);

        faucetToken(address(dodo), user1, 10 * 1e18);
        check = d3UserQuota.checkQuota(user1, address(token1), 100);
        assertEq(check, true);
        check = d3UserQuota.checkQuota(user1, address(token1), 100 + 1);
        assertEq(check, false);

        faucetToken(address(dodo), user1, 200 * 1e18);
        check = d3UserQuota.checkQuota(user1, address(token1), 1000);
        assertEq(check, true);
        check = d3UserQuota.checkQuota(user1, address(token1), 1000 + 1);
        assertEq(check, false);

        faucetToken(address(dodo), user1, 1000 * 1e18);
        check = d3UserQuota.checkQuota(user1, address(token1), 10000);
        assertEq(check, true);
        check = d3UserQuota.checkQuota(user1, address(token1), 10000 + 1);
        assertEq(check, false);

        faucetToken(address(dodo), user1, 10000 * 1e18);
        check = d3UserQuota.checkQuota(user1, address(token1), 10000);
        assertEq(check, true);
        check = d3UserQuota.checkQuota(user1, address(token1), 10000 + 1);
        assertEq(check, false);
    }
}
