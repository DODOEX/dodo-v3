// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import {D3MM} from "../D3Pool/D3MM.sol";

contract D3MMNoBorrow is D3MM {

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

    /// @notice get D3MM contract version
    function version() external pure virtual override returns (string memory) {
        return "D3MM No Borrow";
    }
}
