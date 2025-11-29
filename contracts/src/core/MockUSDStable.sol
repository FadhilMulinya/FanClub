//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUsdStable is ERC20{
    constructor(address _users, uint256 _amount) ERC20("USD Stable Mock", "MUSD"){
        _mint(_users, _amount);
    }

    function mint(address _user, uint256 _amount) public {
        _mint(_user, _amount);
    }
}