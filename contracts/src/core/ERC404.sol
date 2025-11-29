// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Ownable.sol";

abstract contract ERC404 is Ownable {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event ERC20Transfer(address indexed from, address indexed to, uint256 amount);
    
    error InvalidRecipient();
    error InvalidSender();
    
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 10 * 10**18; // 10 NFTs
    uint256 public minted;
    
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256[]) internal _owned;
    mapping(address => bool) public whitelist;
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) Ownable(_owner) {
        name = _name;
        symbol = _symbol;
        balanceOf[_owner] = totalSupply; // CONTRACT OWNS ALL
    }
    
    function setWhitelist(address target, bool state) external onlyOwner {
        whitelist[target] = state;
    }
    
    function ownerOf(uint256 id) public view returns (address) {
        return _ownerOf[id];
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        return _transfer(msg.sender, to, amount);
    }
    
    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        uint256 unit = 1e18;
        uint256 balanceFromBefore = balanceOf[from];
        uint256 balanceToBefore = balanceOf[to];
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        
        if (!whitelist[from]) {
            uint256 toBurn = (balanceFromBefore / unit) - (balanceOf[from] / unit);
            for (uint256 i = 0; i < toBurn; i++) _burn(from);
        }
        
        if (!whitelist[to]) {
            uint256 toMint = (balanceOf[to] / unit) - (balanceToBefore / unit);
            for (uint256 i = 0; i < toMint; i++) _mint(to);
        }
        
        emit ERC20Transfer(from, to, amount);
        return true;
    }
    
    function _mint(address to) internal {
        unchecked { minted++; }
        uint256 id = minted;
        _ownerOf[id] = to;
        _owned[to].push(id);
        emit Transfer(address(0), to, id);
    }
    
    function _burn(address from) internal {
        uint256 id = _owned[from][_owned[from].length - 1];
        _owned[from].pop();
        delete _ownerOf[id];
        emit Transfer(from, address(0), id);
    }
    
    function tokenURI(uint256 id) public view virtual returns (string memory);
}