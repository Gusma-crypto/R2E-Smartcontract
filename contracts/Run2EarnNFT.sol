// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Run2EarnNFT is ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    uint256 private _nextTokenId;

    enum Rarity { Common, Rare, Epic, Legendary }
    
    struct NFTAttributes {
        Rarity rarity;
        uint256 stamina;        // Max session duration in seconds
        uint256 speedEfficiency; // Bonus token per km (percentage)
        uint256 energyRecovery; // Cooldown time in seconds
        uint256 level;
        uint256 totalDistance;  // Total km run
        uint256 createdAt;
        uint256 lastUpgraded;
    }
    
    mapping(uint256 => NFTAttributes) public tokenAttributes;
    mapping(address => uint256) public userToTokenId;
    
    uint256 public mintFee = 0.001 ether;
    address public treasury;
    
    event NFTMinted(address indexed to, uint256 tokenId, Rarity rarity);
    event NFTUpgraded(uint256 tokenId, Rarity newRarity, uint256 newLevel);
    event AttributesUpdated(uint256 tokenId, uint256 totalDistance, uint256 newLevel);

    constructor(address _treasury) ERC721("Run2Earn Avatar", "R2ENFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        treasury = _treasury;
        _nextTokenId = 1; // Start token IDs from 1
    }

    function safeMint(address to, string memory uri, Rarity rarity) 
        external 
        payable 
        onlyRole(MINTER_ROLE)
        nonReentrant
        returns (uint256) 
    {
        require(msg.value >= mintFee, "Insufficient mint fee");
        require(userToTokenId[to] == 0, "User already has NFT");
        require(to != address(0), "Cannot mint to zero address");
        
        uint256 tokenId = _nextTokenId++;
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        // Set initial attributes berdasarkan rarity
        NFTAttributes memory attributes = NFTAttributes({
            rarity: rarity,
            stamina: getBaseStamina(rarity),
            speedEfficiency: getBaseSpeed(rarity),
            energyRecovery: getBaseRecovery(rarity),
            level: 1,
            totalDistance: 0,
            createdAt: block.timestamp,
            lastUpgraded: block.timestamp
        });
        
        tokenAttributes[tokenId] = attributes;
        userToTokenId[to] = tokenId;
        
        // Transfer mint fee ke treasury
        (bool success, ) = treasury.call{value: msg.value}("");
        require(success, "Fee transfer failed");
        
        emit NFTMinted(to, tokenId, rarity);
        return tokenId;
    }

    function updateRunningStats(uint256 tokenId, uint256 distance) 
        external 
        onlyRole(UPGRADER_ROLE) 
    {
        require(_ownerOf(tokenId) != address(0), "NFT doesn't exist");
        
        NFTAttributes storage attributes = tokenAttributes[tokenId];
        attributes.totalDistance += distance;
        
        // Check level up
        uint256 newLevel = calculateLevel(attributes.totalDistance);
        if (newLevel > attributes.level) {
            attributes.level = newLevel;
            
            // Check rarity upgrade
            Rarity newRarity = calculateRarity(newLevel, attributes.totalDistance);
            if (newRarity > attributes.rarity) {
                attributes.rarity = newRarity;
                attributes.stamina = getBaseStamina(newRarity);
                attributes.speedEfficiency = getBaseSpeed(newRarity);
                attributes.energyRecovery = getBaseRecovery(newRarity);
                
                emit NFTUpgraded(tokenId, newRarity, newLevel);
            }
            
            attributes.lastUpgraded = block.timestamp;
            emit AttributesUpdated(tokenId, attributes.totalDistance, newLevel);
        }
    }

    function getBaseStamina(Rarity rarity) internal pure returns (uint256) {
        if (rarity == Rarity.Common) return 30 * 60; // 30 minutes in seconds
        if (rarity == Rarity.Rare) return 45 * 60;   // 45 minutes
        if (rarity == Rarity.Epic) return 60 * 60;   // 60 minutes
        return 90 * 60; // 90 minutes Legendary
    }

    function getBaseSpeed(Rarity rarity) internal pure returns (uint256) {
        if (rarity == Rarity.Common) return 100; // 1.0x
        if (rarity == Rarity.Rare) return 110;   // 1.1x
        if (rarity == Rarity.Epic) return 125;   // 1.25x
        return 150; // 1.5x Legendary
    }

    function getBaseRecovery(Rarity rarity) internal pure returns (uint256) {
        if (rarity == Rarity.Common) return 4 * 60 * 60; // 4 hours in seconds
        if (rarity == Rarity.Rare) return 3 * 60 * 60;   // 3 hours
        if (rarity == Rarity.Epic) return 2 * 60 * 60;   // 2 hours
        return 1 * 60 * 60; // 1 hour Legendary
    }

    function calculateLevel(uint256 totalDistance) public pure returns (uint256) {
        if (totalDistance >= 1000) return 10; // Champion
        if (totalDistance >= 500) return 7;   // Athlete
        if (totalDistance >= 100) return 4;   // Runner
        if (totalDistance >= 10) return 2;    // Beginner
        return 1; // Newbie
    }

    function calculateRarity(uint256 level, uint256 distance) public pure returns (Rarity) {
        if (distance >= 1000 || level >= 10) return Rarity.Legendary;
        if (distance >= 500 || level >= 7) return Rarity.Epic;
        if (distance >= 100 || level >= 4) return Rarity.Rare;
        return Rarity.Common;
    }

    function getNFTAttributes(uint256 tokenId) 
        external 
        view 
        returns (NFTAttributes memory) 
    {
        require(_ownerOf(tokenId) != address(0), "NFT doesn't exist");
        return tokenAttributes[tokenId];
    }

    function setMintFee(uint256 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintFee = newFee;
    }

    function updateTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newTreasury != address(0), "Invalid treasury address");
        treasury = newTreasury;
    }

    // Override functions required by multiple inheritance
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        address from = _ownerOf(tokenId);
        
        // Update user mapping when NFT is transferred
        if (from != address(0)) {
            userToTokenId[from] = 0;
        }
        if (to != address(0)) {
            userToTokenId[to] = tokenId;
        }
        
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}