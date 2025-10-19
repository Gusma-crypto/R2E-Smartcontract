// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RunToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("RunToken", "R2E") {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
}
