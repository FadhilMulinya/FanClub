//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";


contract CountryToken is ERC20,AccessControl{

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address _escrowContract) ERC20("Kenya Shilling Token", "KES"){
        _grantRole(MINTER_ROLE, _escrowContract);
    }

    function mint(address _to, uint256 _value) public onlyRole(MINTER_ROLE) returns (bool){
        require(_to != address(0), "Cant mint to zero address");
        require(_value != 0 , "Cant mint zero tokens");
        
        uint256 amount = _value *10 ** uint256(decimals());

        _mint(_to, amount);

        return true;
    }
}