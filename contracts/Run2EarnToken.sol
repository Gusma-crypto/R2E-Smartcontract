// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Run2EarnToken is ERC20, ERC20Burnable, ERC20Votes, Ownable, ReentrancyGuard {
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18;
    
    // Distribution allocations
    address public rewardsPool;
    address public teamWallet;
    address public ecosystemWallet;
    address public marketingWallet;
    address public treasuryWallet;
    
    // Vesting untuk team
    uint256 public teamVestingStart;
    uint256 public constant TEAM_VESTING_DURATION = 730 days; // 2 years in days
    uint256 public constant TEAM_ALLOCATION = 20_000_000 * 10 ** 18;
    
    // Track claimed team tokens
    uint256 public teamTokensClaimed;
    
    event TokensDistributed(address indexed to, uint256 amount, string allocation);
    event TeamTokensClaimed(address indexed teamWallet, uint256 amount);
    event WalletUpdated(string walletType, address indexed oldWallet, address indexed newWallet);

    constructor(
        address _rewardsPool,
        address _teamWallet,
        address _ecosystemWallet,
        address _marketingWallet,
        address _treasuryWallet
    ) ERC20("Run2Earn Health", "R2E") Ownable(msg.sender) {
        require(_rewardsPool != address(0), "Invalid rewards pool");
        require(_teamWallet != address(0), "Invalid team wallet");
        require(_ecosystemWallet != address(0), "Invalid ecosystem wallet");
        require(_marketingWallet != address(0), "Invalid marketing wallet");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        
        rewardsPool = _rewardsPool;
        teamWallet = _teamWallet;
        ecosystemWallet = _ecosystemWallet;
        marketingWallet = _marketingWallet;
        treasuryWallet = _treasuryWallet;
        teamVestingStart = block.timestamp;
        
        // Mint tokens sesuai distribusi
        _mint(rewardsPool, 40_000_000 * 10 ** 18); // 40% User Rewards
        _mint(address(this), 20_000_000 * 10 ** 18); // 20% Team (vested)
        _mint(ecosystemWallet, 15_000_000 * 10 ** 18); // 15% Ecosystem
        _mint(marketingWallet, 10_000_000 * 10 ** 18); // 10% Marketing
        _mint(treasuryWallet, 5_000_000 * 10 ** 18); // 5% Treasury
        
        emit TokensDistributed(rewardsPool, 40_000_000 * 10 ** 18, "User Rewards");
        emit TokensDistributed(address(this), 20_000_000 * 10 ** 18, "Team Vesting");
        emit TokensDistributed(ecosystemWallet, 15_000_000 * 10 ** 18, "Ecosystem");
        emit TokensDistributed(marketingWallet, 10_000_000 * 10 ** 18, "Marketing");
        emit TokensDistributed(treasuryWallet, 5_000_000 * 10 ** 18, "Treasury");
    }

    function claimTeamTokens() external nonReentrant {
        require(msg.sender == teamWallet, "Only team wallet");
        require(block.timestamp >= teamVestingStart, "Vesting not started");
        
        uint256 claimable = _calculateClaimableTeamTokens();
        require(claimable > 0, "No tokens to claim");
        require(balanceOf(address(this)) >= claimable, "Insufficient contract balance");
        
        teamTokensClaimed += claimable;
        _transfer(address(this), teamWallet, claimable);
        
        emit TeamTokensClaimed(teamWallet, claimable);
    }

    function _calculateClaimableTeamTokens() internal view returns (uint256) {
        if (block.timestamp < teamVestingStart) {
            return 0;
        }
        
        uint256 vestedTime = block.timestamp - teamVestingStart;
        uint256 totalVested;
        
        if (vestedTime >= TEAM_VESTING_DURATION) {
            totalVested = TEAM_ALLOCATION;
        } else {
            totalVested = (TEAM_ALLOCATION * vestedTime) / TEAM_VESTING_DURATION;
        }
        
        if (teamTokensClaimed >= totalVested) {
            return 0;
        }
        
        return totalVested - teamTokensClaimed;
    }

    function getClaimableTeamTokens() external view returns (uint256) {
        return _calculateClaimableTeamTokens();
    }

    function getVestingInfo() external view returns (
        uint256 startTime,
        uint256 duration,
        uint256 totalAllocation,
        uint256 claimed,
        uint256 claimable,
        uint256 vestedPercentage
    ) {
        startTime = teamVestingStart;
        duration = TEAM_VESTING_DURATION;
        totalAllocation = TEAM_ALLOCATION;
        claimed = teamTokensClaimed;
        claimable = _calculateClaimableTeamTokens();
        
        if (block.timestamp >= teamVestingStart) {
            uint256 vestedTime = block.timestamp - teamVestingStart;
            if (vestedTime >= TEAM_VESTING_DURATION) {
                vestedPercentage = 100 * 10 ** 18; // 100% dengan 18 decimals
            } else {
                vestedPercentage = (vestedTime * 100 * 10 ** 18) / TEAM_VESTING_DURATION;
            }
        } else {
            vestedPercentage = 0;
        }
    }

    function updateTeamWallet(address newTeamWallet) external onlyOwner {
        require(newTeamWallet != address(0), "Invalid team wallet");
        require(newTeamWallet != teamWallet, "Same as current wallet");
        
        emit WalletUpdated("Team", teamWallet, newTeamWallet);
        teamWallet = newTeamWallet;
    }

    function updateRewardsPool(address newRewardsPool) external onlyOwner {
        require(newRewardsPool != address(0), "Invalid rewards pool");
        require(newRewardsPool != rewardsPool, "Same as current pool");
        
        emit WalletUpdated("RewardsPool", rewardsPool, newRewardsPool);
        rewardsPool = newRewardsPool;
    }

    function updateEcosystemWallet(address newEcosystemWallet) external onlyOwner {
        require(newEcosystemWallet != address(0), "Invalid ecosystem wallet");
        require(newEcosystemWallet != ecosystemWallet, "Same as current wallet");
        
        emit WalletUpdated("Ecosystem", ecosystemWallet, newEcosystemWallet);
        ecosystemWallet = newEcosystemWallet;
    }

    function updateMarketingWallet(address newMarketingWallet) external onlyOwner {
        require(newMarketingWallet != address(0), "Invalid marketing wallet");
        require(newMarketingWallet != marketingWallet, "Same as current wallet");
        
        emit WalletUpdated("Marketing", marketingWallet, newMarketingWallet);
        marketingWallet = newMarketingWallet;
    }

    function updateTreasuryWallet(address newTreasuryWallet) external onlyOwner {
        require(newTreasuryWallet != address(0), "Invalid treasury wallet");
        require(newTreasuryWallet != treasuryWallet, "Same as current wallet");
        
        emit WalletUpdated("Treasury", treasuryWallet, newTreasuryWallet);
        treasuryWallet = newTreasuryWallet;
    }

    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "Cannot recover native token");
        IERC20(tokenAddress).transfer(owner(), amount);
    }

    // The following functions are overrides required by Solidity

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}