// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {D3Trading} from "./D3Trading.sol";
import {IFeeRateModel} from "../../intf/IFeeRateModel.sol";
import {ID3Maker} from "../intf/ID3Maker.sol";

/// @title D3MM - DODO V3 Market Making Pool
/// @notice This contract inherits from D3Trading, providing more view functions.
contract D3MM is D3Trading {
    /// @notice Initializes the D3MM pool with the provided parameters
    /// @param creator The address of the pool creator
    /// @param maker The address of the D3Maker contract
    /// @param vault The address of the vault contract
    /// @param oracle The address of the oracle contract
    /// @param feeRateModel The address of the fee rate model contract
    /// @param maintainer The address of the maintainer contract
    function init(
        address creator,
        address maker,
        address vault,
        address oracle,
        address feeRateModel,
        address maintainer
    ) external {
        initOwner(creator);
        state._CREATOR_ = creator;
        state._D3_VAULT_ = vault;
        state._ORACLE_ = oracle;
        state._MAKER_ = maker;
        state._FEE_RATE_MODEL_ = feeRateModel;
        state._MAINTAINER_ = maintainer;
    }

    /// @notice Sets a new D3Maker contract for the pool
    /// @param newMaker The address of the new D3Maker contract
    function setNewMaker(address newMaker) external onlyOwner {
        state._MAKER_ = newMaker;
        allFlag = 0;
    }

    /// @notice Returns the address of the pool creator
    function _CREATOR_() external view returns(address) {
        return state._CREATOR_;
    }

    /// @notice Returns the fee rate for a given token
    /// @param token The address of the token
    function getFeeRate(address token) external view returns(uint256 feeRate) {
        return IFeeRateModel(state._FEE_RATE_MODEL_).getFeeRate(token);
    }

    /// @notice Returns the list of tokens in the pool
    function getPoolTokenlist() external view returns(address[] memory) {
        return ID3Maker(state._MAKER_).getPoolTokenListFromMaker();
    }

    /// @notice Returns the list of tokens deposited in the pool
    function getDepositedTokenList() external view returns (address[] memory) {
        return state.depositedTokenList;
    }

    /// @notice Returns the basic information of the pool
    function getD3MMInfo() external view returns (address vault, address oracle, address maker, address feeRateModel, address maintainer) {
        vault = state._D3_VAULT_;
        oracle = state._ORACLE_;
        maker = state._MAKER_;
        feeRateModel = state._FEE_RATE_MODEL_;
        maintainer = state._MAINTAINER_;
    }

    /// @notice Returns the reserve of a given token in the pool
    /// @param token The address of the token
    function getTokenReserve(address token) external view returns (uint256) {
        return state.balances[token];
    }

    /// @notice Returns the version of the D3MM contract
    function version() external pure virtual returns (string memory) {
        return "D3MM 1.0.0";
    }
}
