// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {D3MM} from "../D3Pool/D3MM.sol";

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

    /// @notice get D3MM contract version
    function version() external pure virtual override returns (string memory) {
        return "D3MMNoBorrow 1.0.0";
    }
}
