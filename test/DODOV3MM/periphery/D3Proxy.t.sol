/*

    Copyright 2023 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity 0.8.16;

import "../../TestContext.t.sol";

contract D3ProxyTest is TestContext {
    address public _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    struct SwapCallbackData {
        bytes data;
        address payer;
    }

    function setUp() public {
        contextBasic();
        setVaultAsset();
        mintPoolCreator();
        setPoolAsset();

        vm.deal(poolCreator, 10 ether);
    }

    function makerDepositETH() public {
        vm.prank(poolCreator);
        d3Proxy.makerDeposit{value: 3 ether}(address(d3MM), _ETH_ADDRESS_, 3 ether);
        
        vm.deal(user1, 3 ether);
    }

    function testUserWithdrawToken() public {
        
        (address dToken,,,,,,,,,,) = d3Vault.getAssetInfo(address(token1));

        vm.prank(user1);
        D3Token(dToken).approve(address(dodoApprove), type(uint256).max);
        vm.prank(user1);
        d3Proxy.userWithdraw(user1, address(token1), 1e8, 0);
    }

    function testMakerDepositETH() public {
        uint256 beforeRatio = d3Vault.getCollateralRatio(address(d3MM));

        // construct makerdeposit data
        bytes memory depositDataBytes =
            abi.encodeWithSignature("makerDeposit(address,address,uint256)", address(d3MM), _ETH_ADDRESS_, 3 ether);

        // construct refund data
        bytes memory refundData = abi.encodeWithSignature("refundETH()");
        // construct multicall data
        bytes[] memory mulData = new bytes[](2);
        mulData[0] = depositDataBytes;
        mulData[1] = refundData;

        vm.prank(poolCreator);
        d3Proxy.multicall{value: 3 ether}(mulData);

        vm.prank(poolCreator);
        vm.expectRevert(bytes("D3PROXY_PAYMENT_NOT_MATCH"));
        d3Proxy.makerDeposit{value: 4 ether}(address(d3MM), _ETH_ADDRESS_, 3 ether);

        uint256 wethBalance = d3MM.getTokenReserve(address(weth));
        assertEq(wethBalance, 3 ether);
        uint256 afterRatio = d3Vault.getCollateralRatio(address(d3MM));
        assertEq(afterRatio, beforeRatio);
    }

    function testUserDepositETH() public {
        vm.prank(vaultOwner);
        d3Vault.addNewToken(
            address(weth), // token
            1000 * 1e18, // max deposit
            500 * 1e18, // max collateral
            90 * 1e16, // collateral weight: 90%
            110 * 1e16, // debtWeight: 110%
            10 * 1e16 // reserve factor: 10%
        );
        (,,,,,,,,,, uint256 bVaultReserve) = d3Vault.getAssetInfo(address(weth));

        vm.deal(user1, 3 ether);
        vm.prank(user1);
        d3Proxy.userDeposit{value: 1 ether}(user1, _ETH_ADDRESS_, 1 ether, 1 ether);
        (,,,,,,,,,, uint256 aVaultReserve) = d3Vault.getAssetInfo(address(weth));
        assertEq(aVaultReserve - bVaultReserve, 1 ether);

        // minReceive protection
        vm.expectRevert(bytes("D3PROXY_MIN_DTOKEN_AMOUNT_FAIL"));
        vm.prank(user1);
        d3Proxy.userDeposit{value: 1 ether}(user1, _ETH_ADDRESS_, 1 ether, 1.1 ether);
    }

    function testUserWithdrawETH() public {
        testUserDepositETH();

        uint256 bBalance = user1.balance;
        (address dToken,,,,,,,,,, uint256 bVaultReserve) = d3Vault.getAssetInfo(address(weth));

        vm.prank(user1);
        D3Token(dToken).approve(address(dodoApprove), type(uint256).max);
        // min receive protection
        vm.expectRevert(bytes("D3PROXY_MIN_RECEIVE_FAIL"));
        vm.prank(user1);
        d3Proxy.userWithdraw(user1, _ETH_ADDRESS_, 0.5 ether, 0.6 ether);

        vm.prank(user1);
        d3Proxy.userWithdraw(user1, _ETH_ADDRESS_, 0.5 ether, 0.5 ether);
        
        uint256 aBalance = user1.balance;
        assertEq(aBalance - bBalance, 0.5 ether);
        (,,,,,,,,,, uint256 aVaultReserve) = d3Vault.getAssetInfo(address(weth));
        assertEq(bVaultReserve - aVaultReserve, 0.5 ether);
    }

    function testSellETHToToken() public {
        // token3 price is 1, weth is 12
        makerDepositETH();

        // construct swap bytes data
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;


        vm.prank(user1);
        uint256 receiveToToken = d3Proxy.sellTokens{value: 1 ether}(
            address(d3MM),
            user1, 
            _ETH_ADDRESS_, 
            address(token1), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        assertEq(receiveToToken, 921436); //0.00919, weth is 12, token1 is 1300, near 0.00923
        //console.log("sell directly:", receiveToToken);

        uint256 beforeBalance2 = user1.balance;
        uint256 beforeBalance3 = token3.balanceOf(user1);

        bytes memory swapDataBytes = abi.encodeWithSignature(
            "sellTokens("
            "address,"
            "address,"
            "address,"
            "address,"
            "uint256,"
            "uint256,"
            "bytes,"
            "uint256"
            ")", 
            address(d3MM),
            user1,
            _ETH_ADDRESS_, 
            address(token3), 
            1 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // construct refund data
        bytes memory refundData = abi.encodeWithSignature("refundETH()");
        // construct multicall data
        bytes[] memory mulData = new bytes[](2);
        mulData[0] = swapDataBytes;
        mulData[1] = refundData;

        vm.prank(user1);
        d3Proxy.multicall{value: 1 ether}(mulData);


        uint256 afterBalance2 = user1.balance;
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log("weth:", beforeBalance2 - afterBalance2);
        //console.log(afterBalance3 - beforeBalance3);
        assertEq(beforeBalance2 - afterBalance2, 1 ether);
        assertEq(afterBalance3 - beforeBalance3, 11974218097561551094); // 11.9, token3 is 1, near 12

        // if msg.value mismatch fromAmount, should revert
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        vm.expectRevert(bytes("D3PROXY_VALUE_INVALID"));
        d3Proxy.multicall{value: 2 ether}(mulData);
    }

    function testBuyETHToToken() public {
        makerDepositETH();

        (uint256 payFromAmount, , , ,) = d3MM.queryBuyTokens(address(weth), address(token2), 1 ether);
        uint256 beforeBalance2 = user1.balance;
        uint256 beforeBalance3 = token2.balanceOf(user1);

        // construct swap bytes data
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        /*
        uint256 receiveToToken = d3Proxy.buyTokens(
            address(d3MM),
            user1, 
            _ETH_ADDRESS, 
            address(token3), 
            1 ether, 
            1 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );
        */

        bytes memory swapDataBytes = abi.encodeWithSignature(
            "buyTokens("
            "address,"
            "address,"
            "address,"
            "address,"
            "uint256,"
            "uint256,"
            "bytes,"
            "uint256"
            ")", 
            address(d3MM),
            user1,
            _ETH_ADDRESS_, 
            address(token2), 
            1 ether, 
            1.5 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // construct refund data
        bytes memory refundData = abi.encodeWithSignature("refundETH()");
        // construct multicall data
        bytes[] memory mulData = new bytes[](2);
        mulData[0] = swapDataBytes;
        mulData[1] = refundData;

        vm.prank(user1);
        d3Proxy.multicall{value: 1.5 ether}(mulData);

        uint256 afterBalance2 = user1.balance;
        uint256 afterBalance3 = token2.balanceOf(user1);

        //console.log(payFromAmount);
        //console.log(beforeBalance2 - afterBalance2);
        assertEq(beforeBalance2 - afterBalance2, 1001809084464781831);
        assertEq(beforeBalance2 - afterBalance2, payFromAmount);
        assertEq(afterBalance3 - beforeBalance3, 1 ether);
    }

    function testSellTokenToETH() public {
        makerDepositETH();

        uint256 beforeBalance2 = user1.balance;
        uint256 beforeBalance3 = token3.balanceOf(user1);

        // construct swap bytes data
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        bytes memory swapDataBytes = abi.encodeWithSignature(
            "sellTokens("
            "address,"
            "address,"
            "address,"
            "address,"
            "uint256,"
            "uint256,"
            "bytes,"
            "uint256"
            ")", 
            address(d3MM),
            user1,
            address(token3), 
            _ETH_ADDRESS_, 
            12 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // construct refund data
        bytes memory refundData = abi.encodeWithSignature("withdrawWETH(address,uint256)", user1, 0);
        // construct multicall data
        bytes[] memory mulData = new bytes[](2);
        mulData[0] = swapDataBytes;
        mulData[1] = refundData;

        vm.prank(user1);
        //d3Proxy.multicall(mulData);
        d3Proxy.sellTokens(
            address(d3MM),
            user1,
            address(token3), 
            _ETH_ADDRESS_, 
            12 ether, 
            0, 
            abi.encode(swapData),
            block.timestamp + 1000
        );


        uint256 afterBalance2 = user1.balance;
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log("eth:", afterBalance2 - beforeBalance2);
        //console.log(beforeBalance3 - afterBalance3 );
        assertEq(afterBalance2 - beforeBalance2, 998365344116153351); // 0.99, suppose 1
        assertEq(beforeBalance3 - afterBalance3, 12 ether);
    }

    function testBuyTokenToETH() public {
        makerDepositETH();

        uint256 beforeBalance2 = user1.balance;
        uint256 beforeBalance3 = token3.balanceOf(user1);

        // construct swap bytes data
        SwapCallbackData memory swapData;
        swapData.data = "";
        swapData.payer = user1;

        bytes memory swapDataBytes = abi.encodeWithSignature(
            "buyTokens("
            "address,"
            "address,"
            "address,"
            "address,"
            "uint256,"
            "uint256,"
            "bytes,"
            "uint256"
            ")", 
            address(d3MM),
            user1,
            address(token3), 
            _ETH_ADDRESS_, 
            1 ether, 
            30 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );

        // construct refund data
        bytes memory refundData = abi.encodeWithSignature("withdrawWETH(address,uint256)", user1, 0);
        // construct multicall data
        bytes[] memory mulData = new bytes[](2);
        mulData[0] = swapDataBytes;
        mulData[1] = refundData;

        vm.prank(user1);
        //d3Proxy.multicall(mulData);
        d3Proxy.buyTokens(
            address(d3MM),
            user1,
            address(token3), 
            _ETH_ADDRESS_, 
            1 ether, 
            30 ether, 
            abi.encode(swapData),
            block.timestamp + 1000
        );


        uint256 afterBalance2 = user1.balance;
        uint256 afterBalance3 = token3.balanceOf(user1);

        //console.log("eth:", afterBalance2 - beforeBalance2);
        //console.log(beforeBalance3 - afterBalance3 );
        assertEq(afterBalance2 - beforeBalance2, 1 ether);
        assertEq(beforeBalance3 - afterBalance3, 12019646772033312087);
    }

    function testSwapCallBack() public {
        // if not called by D3MM
        bytes memory data;
        vm.expectRevert(bytes("D3PROXY_CALLBACK_INVALID"));
        d3Proxy.d3MMSwapCallBack(address(token1), 1 ether, data);
    }

    function testWithdrawWETH() public {
        vm.deal(user1, 2 ether);
        vm.startPrank(user1);
        weth.deposit{value: 2 ether}();
        weth.transfer(address(d3Proxy), 2 ether);
        assertEq(user1.balance, 0);
        assertEq(weth.balanceOf(address(d3Proxy)), 2 ether);

        vm.expectRevert(bytes("D3PROXY_WETH_NOT_ENOUGH"));
        d3Proxy.withdrawWETH(user1, 3 ether);

        d3Proxy.withdrawWETH(user1, 2 ether);
        assertEq(weth.balanceOf(address(d3Proxy)), 0 ether);
        assertEq(user1.balance, 2 ether);
    }
}
