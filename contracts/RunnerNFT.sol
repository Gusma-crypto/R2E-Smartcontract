// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RunnerNFT is ERC721URIStorage, Ownable {
    uint256 public nextId;

    constructor() ERC721("R2E Avatar", "RUN") Ownable(msg.sender){}

    function mint(address to, string memory uri) external onlyOwner {
        uint256 tokenId = nextId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
}
