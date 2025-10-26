// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
contract R2EToken is ERC20, Ownable{
    constructor() ERC20("RUNTOEARN","R2E") Ownable(msg.sender){
        _mint(msg.sender, 100_000_000*10**decimals());
    }

    function mintReward(address to, uint256 amount) external onlyOwner(){
        _mint(to, amount);
    }
}