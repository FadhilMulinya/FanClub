// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Ownable {
    address public owner;
    error Unauthorized();
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized");
        _;
    }
    
    constructor(address _owner) {
        owner = _owner;
    }
}