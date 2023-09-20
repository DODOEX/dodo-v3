// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import {IFeeRateModel} from "../intf/IFeeRateModel.sol";
import "../DODOV3MM/lib/InitializableOwnable.sol";

contract MockFeeRateModel is IFeeRateModel, InitializableOwnable {
    uint256 public feeRate;

    function init(address owner, uint256 _feeRate) public {
        initOwner(owner);
        feeRate = _feeRate;
    }

    function setFeeRate(uint256 newFeeRate) public onlyOwner {
        feeRate = newFeeRate;
    }

    function getFeeRate() external view returns(uint256 feerate) {
        return feeRate;
    }

    function testSuccess() public {}
}