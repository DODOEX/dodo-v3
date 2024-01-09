// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/DecimalMath.sol";
import "../intf/ID3Vault.sol";
import "../../intf/ID3Oracle.sol";
import "./D3Storage.sol";

/// @notice pool funding model, manage pool borrow/repay and maker deposi/withdraw
contract D3Funding is D3Storage {
    using SafeERC20 for IERC20;

    /// @notice borrow tokens from vault
    /// @param token The address of the token to borrow
    /// @param amount The amount of tokens to borrow
    function borrow(address token, uint256 amount) external onlyOwner nonReentrant poolOngoing {
        // call vault's poolBorrow function
        ID3Vault(state._D3_VAULT_).poolBorrow(token, amount);
        // approve max, ensure vault could force liquidate
        uint256 allowance = IERC20(token).allowance(address(this), state._D3_VAULT_);
        if(allowance < type(uint256).max) {
            IERC20(token).forceApprove(state._D3_VAULT_, type(uint256).max);
        }

        _updateReserve(token);
        require(checkSafe(), Errors.NOT_SAFE);
        require(checkBorrowSafe(), Errors.NOT_BORROW_SAFE);
    }

    /// @notice repay vault with certain amount of borrowed assets 
    /// @param token The address of the token to repay
    /// @param amount The amount of tokens to repay
    function repay(address token, uint256 amount) external onlyOwner nonReentrant poolOngoing {
        // call vault's poolRepay
        ID3Vault(state._D3_VAULT_).poolRepay(token, amount);

        _updateReserve(token);
        require(checkSafe(), Errors.NOT_SAFE);
    }

    /// @notice repay vault all debt of this token
    /// @param token The address of the token to repay all debt
    function repayAll(address token) external onlyOwner nonReentrant poolOngoing {
        ID3Vault(state._D3_VAULT_).poolRepayAll(token);

        _updateReserve(token);
        require(checkSafe(), Errors.NOT_SAFE);

    }

    /// @notice used through liquidation
    /// @param token The address of the token to update reserve
    function updateReserveByVault(address token) external onlyVault {
        uint256 allowance = IERC20(token).allowance(address(this), state._D3_VAULT_);
        if(allowance < type(uint256).max) {
            IERC20(token).forceApprove(state._D3_VAULT_, type(uint256).max);
        }
        _updateReserve(token);
    }

    /// @notice maker deposit, anyone could deposit but only maker could withdraw
    /// @param token The address of the token to deposit
    function makerDeposit(address token) external nonReentrant poolOngoing {
        require(ID3Oracle(state._ORACLE_).isFeasible(token), Errors.TOKEN_NOT_FEASIBLE);
        if (!state.hasDepositedToken[token]) {
            state.hasDepositedToken[token] = true;
            state.depositedTokenList.push(token);
        }
        // transfer in from proxies
        uint256 tokenInAmount = IERC20(token).balanceOf(address(this)) - state.balances[token];
        _updateReserve(token);
        // if token in tokenlist, approve max, ensure vault could force liquidate
        uint256 allowance = IERC20(token).allowance(address(this), state._D3_VAULT_);
        if(_checkTokenInTokenlist(token) && allowance < type(uint256).max) {
            IERC20(token).forceApprove(state._D3_VAULT_, type(uint256).max);
        }
        require(checkSafe(), Errors.NOT_SAFE);

        emit MakerDeposit(token, tokenInAmount);
    }

    /// @notice maker withdraw, only maker could withdraw
    /// @param to The address to receive the withdrawn tokens
    /// @param token The address of the token to withdraw
    /// @param amount The amount of tokens to withdraw
    function makerWithdraw(address to, address token, uint256 amount) external onlyOwner nonReentrant poolOngoing {
        IERC20(token).safeTransfer(to, amount);

        _updateReserve(token);
        require(checkSafe(), Errors.NOT_SAFE);
        require(checkBorrowSafe(), Errors.NOT_BORROW_SAFE);

        emit MakerWithdraw(to, token, amount);
    }

    /// @notice check if the pool is safe
    function checkSafe() public view returns (bool) {
        return ID3Vault(state._D3_VAULT_).checkSafe(address(this));
    }

    /// @notice check if the pool is safe when borrowing asset
    function checkBorrowSafe() public view returns (bool) {
        return ID3Vault(state._D3_VAULT_).checkBorrowSafe(address(this));
    }

    /// @notice check if the pool can be liquidated
    function checkCanBeLiquidated() public view returns (bool) {
        return ID3Vault(state._D3_VAULT_).checkCanBeLiquidated(address(this));
    }

    /// @notice start the liquidation process
    function startLiquidation() external onlyVault {
        isInLiquidation = true;
    }

    /// @notice finish the liquidation process
    function finishLiquidation() external onlyVault {
        isInLiquidation = false;
    }

    /// @notice update the reserve of a token
    /// @param token The address of the token to update reserve
    function _updateReserve(address token) internal {
        state.balances[token] = IERC20(token).balanceOf(address(this));
    }

    /// @notice check if a token is in the token list
    /// @param token The address of the token to check
    /// @return true if the token is in the token list, false otherwise
    function _checkTokenInTokenlist(address token) internal view returns(bool){
        return ID3Vault(state._D3_VAULT_).tokens(token); 
    }
}
