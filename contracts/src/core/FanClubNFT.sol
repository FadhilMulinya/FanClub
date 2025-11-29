// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./ERC404.sol"; 
import {PriceHelper} from "./PriceHelper.sol";
contract FanClubNFT is ERC404 {
    // 🔥 ONLY PRICES NEEDED
    mapping(uint256 => uint256) public livePrice; // Price in cents * 100

    PriceHelper public m_priceHelper;
    
    // 🔥 10 PLAYERS
    string[11] public playerNames = [
        "", "fMESSI", "fRonaldo", "fMbappe", "fHaaland", 
        "fSalah", "fBellingham", "fDeBruyne", "fLewandowski", 
        "fVinicius", "fRodri"
    ];
    
    constructor(address _priceHelper) ERC404("FanClub fNFT", "FAN", msg.sender) {
        // 🔥 CONTRACT OWNS ALL 10 NFTs
        // 🔥 DEFAULT PRICES $0.13
        for (uint256 i = 1; i <= 10; i++) {
            livePrice[i] = 1300; // 13.00 cents * 100
        }
        m_priceHelper = PriceHelper(_priceHelper);
    }

    modifier onlyPriceHelper(){
        require(msg.sender == m_PriceHe)
    }
    
    // 🔥 ONLY FUNCTION: UPDATE PRICES
    // Called by Helper Contract or Owner
    function updatePrice(uint256 id, uint256 price) external {
        // Anyone can call (Somnia Helper Contract)
        // Or restrict: onlyOwner
        require(id >= 1 && id <= 10, "Invalid ID");
        livePrice[id] = price;
    }
    
    // 🔥 SIMPLE METADATA
    function tokenURI(uint256 id) public view override returns (string memory) {
        require(id >= 1 && id <= 10, "Invalid ID");
        
        string memory priceStr = _uint2str(livePrice[id] / 100);
        string memory image = _getPlayerImage(id);
        
        return string(abi.encodePacked(
            'data:application/json;{"name":"',
            playerNames[id],
            '","description":"Live fNFT","image":"',
            image,
            '","attributes":[{"trait_type":"Price","value":"$',
            priceStr, '"}]}'
        ));
    }
    
    // 🔥 HELPER IMAGES
    function _getPlayerImage(uint256 id) internal pure returns (string memory) {
        string[11] memory images;
        images[1] = "https://fanclub.somnia/messi.jpg";
        images[2] = "https://fanclub.somnia/ronaldo.jpg";
        images[3] = "https://fanclub.somnia/mbappe.jpg";
        images[4] = "https://fanclub.somnia/haaland.jpg";
        images[5] = "https://fanclub.somnia/salah.jpg";
        images[6] = "https://fanclub.somnia/bellingham.jpg";
        images[7] = "https://fanclub.somnia/debruyne.jpg";
        images[8] = "https://fanclub.somnia/lewandowski.jpg";
        images[9] = "https://fanclub.somnia/vinicius.jpg";
        images[10] = "https://fanclub.somnia/rodri.jpg";
        
        return images[id];
    }
    
    // 🔥 STRING UTILITY
    function _uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 byteTemp = bytes1(temp);
            bstr[k] = byteTemp;
            _i /= 10;
        }
        return string(bstr);
    }
}