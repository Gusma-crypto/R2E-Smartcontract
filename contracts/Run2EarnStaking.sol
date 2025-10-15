// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Run2EarnNFT.sol";

contract Run2EarnStaking is ReentrancyGuard, AccessControl {
    bytes32 public constant REWARDS_ROLE = keccak256("REWARDS_ROLE");
    
    IERC20 public r2eToken;
    Run2EarnNFT public nftContract;
    
    struct StakingInfo {
        uint256 amount;
        uint256 stakedAt;
        uint256 lastClaimed;
        uint256 rewardDebt;
    }
    
    struct PoolInfo {
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        uint256 totalStaked;
    }
    
    mapping(address => StakingInfo) public stakingInfo;
    mapping(uint256 => uint256) public nftMultipliers; // tokenId -> multiplier (100 = 1.0x)
    
    PoolInfo public stakingPool;
    uint256 public rewardPerBlock;
    uint256 public constant REWARD_MULTIPLIER = 1e12;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event NFTMultiplierSet(uint256 tokenId, uint256 multiplier);
    event RewardPerBlockUpdated(uint256 newRewardPerBlock);
    emergencyWithdrawal(address indexed admin, uint256 amount);

    constructor(
        address _r2eToken,
        address _nftContract,
        uint256 _rewardPerBlock
    ) {
        require(_r2eToken != address(0), "Invalid token address");
        require(_nftContract != address(0), "Invalid NFT contract address");
        require(_rewardPerBlock > 0, "Reward per block must be positive");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REWARDS_ROLE, msg.sender);
        
        r2eToken = IERC20(_r2eToken);
        nftContract = Run2EarnNFT(_nftContract);
        rewardPerBlock = _rewardPerBlock;
        
        stakingPool = PoolInfo({
            allocPoint: 1000,
            lastRewardBlock: block.number,
            accRewardPerShare: 0,
            totalStaked: 0
        });
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        
        updatePool();
        
        StakingInfo storage user = stakingInfo[msg.sender];
        
        // Claim pending rewards if any
        if (user.amount > 0) {
            uint256 pending = (user.amount * stakingPool.accRewardPerShare) / REWARD_MULTIPLIER - user.rewardDebt;
            if (pending > 0) {
                _safeTransferReward(msg.sender, pending);
            }
        }
        
        // Transfer tokens from user to contract
        bool transferSuccess = r2eToken.transferFrom(msg.sender, address(this), amount);
        require(transferSuccess, "Token transfer failed");
        
        // Update user staking info
        user.amount += amount;
        user.rewardDebt = (user.amount * stakingPool.accRewardPerShare) / REWARD_MULTIPLIER;
        user.stakedAt = block.timestamp;
        user.lastClaimed = block.timestamp;
        
        // Update pool total
        stakingPool.totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        
        StakingInfo storage user = stakingInfo[msg.sender];
        require(user.amount >= amount, "Insufficient staked amount");
        
        updatePool();
        
        // Claim pending rewards
        uint256 pending = (user.amount * stakingPool.accRewardPerShare) / REWARD_MULTIPLIER - user.rewardDebt;
        if (pending > 0) {
            _safeTransferReward(msg.sender, pending);
        }
        
        // Update user staking info
        user.amount -= amount;
        user.rewardDebt = (user.amount * stakingPool.accRewardPerShare) / REWARD_MULTIPLIER;
        
        // Update pool total
        stakingPool.totalStaked -= amount;
        
        // Transfer staked tokens back to user
        bool transferSuccess = r2eToken.transfer(msg.sender, amount);
        require(transferSuccess, "Token transfer failed");
        
        emit Unstaked(msg.sender, amount);
    }

    function claimReward() external nonReentrant {
        updatePool();
        
        StakingInfo storage user = stakingInfo[msg.sender];
        require(user.amount > 0, "No staked amount");
        
        uint256 pending = (user.amount * stakingPool.accRewardPerShare) / REWARD_MULTIPLIER - user.rewardDebt;
        require(pending > 0, "No rewards to claim");
        
        // Update reward debt before transfer to prevent reentrancy
        user.rewardDebt = (user.amount * stakingPool.accRewardPerShare) / REWARD_MULTIPLIER;
        user.lastClaimed = block.timestamp;
        
        _safeTransferReward(msg.sender, pending);
        emit RewardClaimed(msg.sender, pending);
    }

    function updatePool() public {
        if (block.number <= stakingPool.lastRewardBlock) {
            return;
        }
        
        if (stakingPool.totalStaked == 0) {
            stakingPool.lastRewardBlock = block.number;
            return;
        }
        
        uint256 multiplier = block.number - stakingPool.lastRewardBlock;
        uint256 reward = multiplier * rewardPerBlock;
        
        stakingPool.accRewardPerShare += (reward * REWARD_MULTIPLIER) / stakingPool.totalStaked;
        stakingPool.lastRewardBlock = block.number;
    }

    function setNFTMultiplier(uint256 tokenId, uint256 multiplier) external onlyRole(REWARDS_ROLE) {
        require(multiplier <= 300, "Multiplier too high"); // Max 3x
        require(multiplier >= 100, "Multiplier too low"); // Min 1x
        nftMultipliers[tokenId] = multiplier;
        emit NFTMultiplierSet(tokenId, multiplier);
    }

    function getPendingReward(address user) external view returns (uint256) {
        StakingInfo storage staker = stakingInfo[user];
        
        uint256 accRewardPerShare = stakingPool.accRewardPerShare;
        uint256 poolTotalStaked = stakingPool.totalStaked;
        
        if (block.number > stakingPool.lastRewardBlock && poolTotalStaked != 0) {
            uint256 multiplier = block.number - stakingPool.lastRewardBlock;
            uint256 reward = multiplier * rewardPerBlock;
            accRewardPerShare += (reward * REWARD_MULTIPLIER) / poolTotalStaked;
        }
        
        return (staker.amount * accRewardPerShare) / REWARD_MULTIPLIER - staker.rewardDebt;
    }

    function getUserStakingInfo(address user) external view returns (
        uint256 stakedAmount,
        uint256 stakedAt,
        uint256 lastClaimed,
        uint256 pendingRewards
    ) {
        StakingInfo storage staker = stakingInfo[user];
        stakedAmount = staker.amount;
        stakedAt = staker.stakedAt;
        lastClaimed = staker.lastClaimed;
        pendingRewards = this.getPendingReward(user);
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_rewardPerBlock > 0, "Reward per block must be positive");
        updatePool();
        rewardPerBlock = _rewardPerBlock;
        emit RewardPerBlockUpdated(_rewardPerBlock);
    }

    function emergencyWithdraw(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be positive");
        
        uint256 contractBalance = r2eToken.balanceOf(address(this));
        require(amount <= contractBalance, "Insufficient contract balance");
        
        bool success = r2eToken.transfer(to, amount);
        require(success, "Emergency withdrawal failed");
        
        emit EmergencyWithdrawal(to, amount);
    }

    function updateTokenContract(address newTokenContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newTokenContract != address(0), "Invalid token contract");
        r2eToken = IERC20(newTokenContract);
    }

    function updateNFTContract(address newNFTContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newNFTContract != address(0), "Invalid NFT contract");
        nftContract = Run2EarnNFT(newNFTContract);
    }

    function _safeTransferReward(address to, uint256 amount) internal {
        uint256 balance = r2eToken.balanceOf(address(this));
        if (amount > balance) {
            r2eToken.transfer(to, balance);
        } else {
            r2eToken.transfer(to, amount);
        }
    }
}