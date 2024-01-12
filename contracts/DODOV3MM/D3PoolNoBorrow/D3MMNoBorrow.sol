// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "../lib/Types.sol";
import "../lib/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {D3MM} from "D3Pool/D3MM.sol";
import {IDODOSwapCallback} from "../intf/IDODOSwapCallback.sol";
import {ID3Maker} from "../intf/ID3Maker.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract D3MMNoBorrow is D3MM {
    using SafeERC20 for IERC20;

    function borrow(address, uint256) external override onlyOwner nonReentrant poolOngoing {
        revert("Borrow Not Allowed");
    }

    function repay(address, uint256) external override onlyOwner nonReentrant poolOngoing {
        revert("Repay Not Allowed");
    }

    /// @notice repay vault all debt of this token
    function repayAll(address) external override onlyOwner nonReentrant poolOngoing {
        revert("Repay Not Allowed");
    }

    function makerDeposit(address token) external override nonReentrant poolOngoing {
        if (!state.hasDepositedToken[token]) {
            state.hasDepositedToken[token] = true;
            state.depositedTokenList.push(token);
        }
        // transfer in from proxies
        uint256 tokenInAmount = IERC20(token).balanceOf(address(this)) - state.balances[token];
        _updateReserve(token);

        emit MakerDeposit(token, tokenInAmount);
    }

    function makerWithdraw(address to, address token, uint256 amount) external override onlyOwner nonReentrant poolOngoing {
        IERC20(token).safeTransfer(to, amount);
        _updateReserve(token);

        emit MakerWithdraw(to, token, amount);
    }

    /// @notice user sell a certain amount of fromToken, get toToken
    function sellToken(
        address to,
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minReceiveAmount,
        bytes calldata data
    ) external override poolOngoing nonReentrant returns (uint256) {
        require(ID3Maker(state._MAKER_).checkHeartbeat(), Errors.HEARTBEAT_CHECK_FAIL);

        _updateCumulative(fromToken);
        _updateCumulative(toToken);

        (uint256 payFromAmount, uint256 receiveToAmount, uint256 vusdAmount, uint256 swapFee, uint256 mtFee) =
            querySellTokens(fromToken, toToken, fromAmount);
        require(receiveToAmount >= minReceiveAmount, Errors.MINRES_NOT_ENOUGH);

        _transferOut(to, toToken, receiveToAmount);

        // external call & swap callback
        IDODOSwapCallback(msg.sender).d3MMSwapCallBack(fromToken, fromAmount, data);
        // transfer mtFee to maintainer
        if(mtFee > 0) {
            _transferOut(state._MAINTAINER_, toToken, mtFee);
        }

        require(
            IERC20(fromToken).balanceOf(address(this)) - state.balances[fromToken] >= fromAmount,
            Errors.FROMAMOUNT_NOT_ENOUGH
        );

        // record swap
        uint256 toTokenDec = IERC20Metadata(toToken).decimals();
        _recordSwap(fromToken, toToken, vusdAmount, Types.parseRealAmount(receiveToAmount + swapFee, toTokenDec));

        emit Swap(to, fromToken, toToken, payFromAmount, receiveToAmount, swapFee, mtFee, 0);
        return receiveToAmount;
    }

    /// @notice user ask for a certain amount of toToken, fromToken's amount will be determined by toToken's amount
    function buyToken(
        address to,
        address fromToken,
        address toToken,
        uint256 quoteAmount,
        uint256 maxPayAmount,
        bytes calldata data
    ) external override poolOngoing nonReentrant returns (uint256) {
        require(ID3Maker(state._MAKER_).checkHeartbeat(), Errors.HEARTBEAT_CHECK_FAIL);

        _updateCumulative(fromToken);
        _updateCumulative(toToken);

        // query amount and transfer out
        (uint256 payFromAmount, uint256 receiveToAmount, uint256 vusdAmount, uint256 swapFee, uint256 mtFee) =
            queryBuyTokens(fromToken, toToken, quoteAmount);
        require(payFromAmount <= maxPayAmount, Errors.MAXPAY_NOT_ENOUGH);

        _transferOut(to, toToken, receiveToAmount);

        // external call & swap callback
        IDODOSwapCallback(msg.sender).d3MMSwapCallBack(fromToken, payFromAmount, data);
        // transfer mtFee to maintainer
        if(mtFee > 0 ) {
            _transferOut(state._MAINTAINER_, toToken, mtFee);
        }

        require(
            IERC20(fromToken).balanceOf(address(this)) - state.balances[fromToken] >= payFromAmount,
            Errors.FROMAMOUNT_NOT_ENOUGH
        );

        // record swap
        uint256 toTokenDec = IERC20Metadata(toToken).decimals();
        _recordSwap(fromToken, toToken, vusdAmount, Types.parseRealAmount(receiveToAmount + swapFee, toTokenDec));

        emit Swap(to, fromToken, toToken, payFromAmount, receiveToAmount, swapFee, mtFee, 1);
        return payFromAmount;
    }

    /// @notice get D3MM contract version
    function version() external pure virtual override returns (string memory) {
        return "D3MMNoBorrow 1.0.0";
    }
}
