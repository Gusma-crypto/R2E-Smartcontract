// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Run2EarnNFT.sol";

contract Run2EarnRewards is ReentrancyGuard, AccessControl {
    bytes32 public constant REWARDS_MANAGER = keccak256("REWARDS_MANAGER");
    
    IERC20 public r2eToken;
    Run2EarnNFT public nftContract;
    
    uint256 public baseRewardPerKm = 10 * 10 ** 18; // 10 R2E per km
    uint256 public constant MAX_DAILY_KM = 42; // Marathon distance
    uint256 public cooldownPeriod = 4 * 60 * 60; // 4 hours in seconds
    
    mapping(address => uint256) public lastActivity;
    mapping(address => uint256) public dailyDistance;
    mapping(address => uint256) public lastDailyReset;
    
    event RewardsClaimed(address indexed user, uint256 distance, uint256 reward, uint256 nftTokenId);
    event BaseRewardUpdated(uint256 newReward);
    event CooldownPeriodUpdated(uint256 newCooldown);

    constructor(address _r2eToken, address _nftContract) {
        require(_r2eToken != address(0), "Invalid token address");
        require(_nftContract != address(0), "Invalid NFT contract address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REWARDS_MANAGER, msg.sender);
        
        r2eToken = IERC20(_r2eToken);
        nftContract = Run2EarnNFT(_nftContract);
    }

    function claimRunningRewards(uint256 distance, uint256 nftTokenId) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        require(distance > 0, "No distance");
        require(distance <= MAX_DAILY_KM, "Exceeds daily limit");
        require(nftTokenId > 0, "Invalid NFT token ID");
        
        address user = msg.sender;
        
        // Check cooldown period
        require(block.timestamp >= lastActivity[user] + cooldownPeriod, "In cooldown");
        
        // Reset daily distance if new day
        if (block.timestamp >= lastDailyReset[user] + 1 days) {
            dailyDistance[user] = 0;
            lastDailyReset[user] = block.timestamp;
        }
        
        require(dailyDistance[user] + distance <= MAX_DAILY_KM, "Exceeds daily limit");
        
        // Verify NFT ownership
        require(nftContract.ownerOf(nftTokenId) == user, "Not NFT owner");
        
        // Get NFT attributes for multiplier
        Run2EarnNFT.NFTAttributes memory attributes = nftContract.getNFTAttributes(nftTokenId);
        require(uint256(attributes.rarity) <= 3, "Invalid NFT rarity"); // 0-3 for Common-Legendary
        
        // Calculate reward with NFT multiplier
        uint256 baseReward = distance * baseRewardPerKm;
        uint256 multiplier = getNFTMultiplier(attributes);
        uint256 totalReward = (baseReward * multiplier) / 100;
        
        // Check contract token balance
        require(r2eToken.balanceOf(address(this)) >= totalReward, "Insufficient reward tokens");
        
        // Update stats
        dailyDistance[user] += distance;
        lastActivity[user] = block.timestamp;
        
        // Update NFT stats
        nftContract.updateRunningStats(nftTokenId, distance);
        
        // Transfer rewards
        bool success = r2eToken.transfer(user, totalReward);
        require(success, "Reward transfer failed");
        
        emit RewardsClaimed(user, distance, totalReward, nftTokenId);
        return totalReward;
    }

    function getNFTMultiplier(Run2EarnNFT.NFTAttributes memory attributes) 
        internal 
        pure 
        returns (uint256) 
    {
        if (attributes.rarity == Run2EarnNFT.Rarity.Common) return 100;    // 1.0x
        if (attributes.rarity == Run2EarnNFT.Rarity.Rare) return 110;      // 1.1x
        if (attributes.rarity == Run2EarnNFT.Rarity.Epic) return 125;      // 1.25x
        if (attributes.rarity == Run2EarnNFT.Rarity.Legendary) return 150; // 1.5x
        return 100;
    }

    function setBaseRewardPerKm(uint256 newReward) external onlyRole(REWARDS_MANAGER) {
        require(newReward > 0, "Reward must be positive");
        baseRewardPerKm = newReward;
        emit BaseRewardUpdated(newReward);
    }

    function setCooldownPeriod(uint256 newCooldown) external onlyRole(DEFAULT_ADMIN_ROLE) {
        cooldownPeriod = newCooldown;
        emit CooldownPeriodUpdated(newCooldown);
    }

    function getEstimatedReward(uint256 distance, uint256 nftTokenId) 
        external 
        view 
        returns (uint256) 
    {
        require(distance > 0 && distance <= MAX_DAILY_KM, "Invalid distance");
        require(nftTokenId > 0, "Invalid NFT token ID");
        
        Run2EarnNFT.NFTAttributes memory attributes = nftContract.getNFTAttributes(nftTokenId);
        uint256 baseReward = distance * baseRewardPerKm;
        uint256 multiplier = getNFTMultiplier(attributes);
        return (baseReward * multiplier) / 100;
    }

    function getUserDailyStatus(address user) 
        external 
        view 
        returns (
            uint256 remainingDailyDistance,
            uint256 nextAvailableTime,
            bool canClaimNow
        ) 
    {
        uint256 currentDailyDistance = dailyDistance[user];
        if (block.timestamp >= lastDailyReset[user] + 1 days) {
            remainingDailyDistance = MAX_DAILY_KM;
        } else {
            remainingDailyDistance = MAX_DAILY_KM - currentDailyDistance;
        }
        
        nextAvailableTime = lastActivity[user] + cooldownPeriod;
        canClaimNow = (block.timestamp >= nextAvailableTime) && (remainingDailyDistance > 0);
    }

    function withdrawTokens(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be positive");
        require(r2eToken.balanceOf(address(this)) >= amount, "Insufficient balance");
        
        bool success = r2eToken.transfer(to, amount);
        require(success, "Token transfer failed");
    }

    function updateNFTContract(address newNFTContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newNFTContract != address(0), "Invalid NFT contract address");
        nftContract = Run2EarnNFT(newNFTContract);
    }

    function updateTokenContract(address newTokenContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newTokenContract != address(0), "Invalid token contract address");
        r2eToken = IERC20(newTokenContract);
    }
}