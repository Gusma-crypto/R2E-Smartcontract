// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract RunToEarn {
    using ECDSA for bytes32;

    IERC20 public token;
    address public trustedSigner;
    mapping(address => bool) public hasClaimed;

    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address tokenAddress, address signer) {
        token = IERC20(tokenAddress);
        trustedSigner = signer;
    }

    function claimReward(uint256 amount, bytes calldata signature) external {
        require(!hasClaimed[msg.sender], "Already claimed");

        // 1) Buat message hash (harus sama dengan yang backend sign)
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, amount));

        // 2) Tambahkan Ethereum signed message prefix manual
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        // 3) Recover signer dari signature
        address recovered = ECDSA.recover(ethSignedHash, signature);
        require(recovered == trustedSigner, "Invalid signature");

        // 4) Eksekusi transfer reward
        hasClaimed[msg.sender] = true;
        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit RewardClaimed(msg.sender, amount);
    }
}
