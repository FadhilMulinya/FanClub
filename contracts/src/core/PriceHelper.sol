// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./FanClubNFT.sol";

contract PriceHelper {
    FanClubNFT public fanNFT;
    
    constructor(FanClubNFT _fanNFT) {
        fanNFT = _fanNFT;
    }
    
    // 🔥 SOMNIA CALLS THIS
    function updatePlayerPrice(uint256 id, uint256 price) external {
        fanNFT.updatePrice(id, price);
    }
    
    // 🔥 BATCH UPDATE
    function updatePrices(uint256[] calldata ids, uint256[] calldata prices) external {
        require(ids.length == prices.length, "Arrays mismatch");
        for (uint256 i = 0; i < ids.length; i++) {
            fanNFT.updatePrice(ids[i], prices[i]);
        }
    }
}