// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "../lib/MakerTypes.sol";
import "../lib/Errors.sol";
import {D3Maker} from "D3Pool/D3Maker.sol";

/// @notice D3MakerFreeSlot is a special type of D3Maker, in which the market maker can set a new token info in an exsiting token slot, which can save gas
contract D3MakerFreeSlot is D3Maker {

    event ReplaceToken(address indexed oldToken, address indexed newToken);

    /// @notice maker set a new token info into an occupied slot, replacing old token info
    /// @param token token's address
    /// @param priceSet packed price, [mid price(16) | mid price decimal(8) | fee rate(16) | ask up rate (16) | bid down rate(16)]
    /// @param amountSet describe ask and bid amount and K, [ask amounts(16) | ask amounts decimal(8) | bid amounts(16) | bid amounts decimal(8) ] = one slot could contains 4 token info
    /// @param stableOrNot describe this token is stable or not, true = stable coin
    /// @param kAsk k of ask curve
    /// @param kBid k of bid curve
    /// @param oldToken old token address
    function setNewTokenAndReplace(
        address token,
        bool stableOrNot,
        uint80 priceSet,
        uint64 amountSet,
        uint16 kAsk,
        uint16 kBid,
        address oldToken
    ) external onlyOwner {
        require(state.priceListInfo.tokenIndexMap[token] == 0, Errors.HAVE_SET_TOKEN_INFO);
        require(state.priceListInfo.tokenIndexMap[oldToken] != 0, Errors.OLD_TOKEN_NOT_FOUND);
        // check amount
        require(kAsk >= 0 && kAsk <= 10000, Errors.K_LIMIT);
        require(kBid >= 0 && kBid <= 10000, Errors.K_LIMIT);

        for (uint256 i = 0; i < poolTokenlist.length; i++) {
            if (poolTokenlist[i] == oldToken) {
                poolTokenlist[i] = token;
                break;
            }
        }

        uint256 tokenIndex = uint256(getOneTokenOriginIndex(oldToken));
        bool isStable = (tokenIndex % 2 == 0);
        require(isStable == stableOrNot, Errors.STABLE_TYPE_NOT_MATCH);

        // remove old token info
        state.tokenMMInfoMap[oldToken].priceInfo = 0;
        state.tokenMMInfoMap[oldToken].amountInfo = 0;
        state.tokenMMInfoMap[oldToken].kAsk = 0;
        state.tokenMMInfoMap[oldToken].kBid = 0;
        state.tokenMMInfoMap[oldToken].tokenIndex = 0;

        // set new token info
        state.tokenMMInfoMap[token].priceInfo = priceSet;
        state.tokenMMInfoMap[token].amountInfo = amountSet;
        state.tokenMMInfoMap[token].kAsk = kAsk;
        state.tokenMMInfoMap[token].kBid = kBid;
        state.heartBeat.lastHeartBeat = block.timestamp;

        // set token price index
        if (stableOrNot) {
            // is stable
            uint256 indexInStable = tokenIndex / 2;
            uint256 innerSlotIndex = indexInStable % MakerTypes.PRICE_QUANTITY_IN_ONE_SLOT;
            uint256 slotIndex = indexInStable / MakerTypes.PRICE_QUANTITY_IN_ONE_SLOT;
            uint256 oldPriceSlot = state.priceListInfo.tokenPriceStable[slotIndex];
            uint256 newPriceSlot = stickPrice(oldPriceSlot, innerSlotIndex, priceSet);
            state.priceListInfo.tokenPriceStable[slotIndex] = newPriceSlot;
        } else {
            uint256 indexInNStable = (tokenIndex - 1) / 2;
            uint256 innerSlotIndex = indexInNStable % MakerTypes.PRICE_QUANTITY_IN_ONE_SLOT;
            uint256 slotIndex = indexInNStable / MakerTypes.PRICE_QUANTITY_IN_ONE_SLOT;
            uint256 oldPriceSlot = state.priceListInfo.tokenPriceNS[slotIndex];
            uint256 newPriceSlot = stickPrice(oldPriceSlot, innerSlotIndex, priceSet);
            state.priceListInfo.tokenPriceNS[slotIndex] = newPriceSlot;
        }
        // to avoid reset the same token, tokenIndexMap record index from 1, but actualIndex = tokenIndex[address] - 1
        state.priceListInfo.tokenIndexMap[token] = tokenIndex + 1;
        state.tokenMMInfoMap[token].tokenIndex = uint16(tokenIndex);

        emit SetNewToken(token);
        emit ReplaceToken(oldToken, token);
    }
}
