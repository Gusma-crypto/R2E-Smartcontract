const hre = require("hardhat");

async function main() {
  const Token = await hre.ethers.getContractFactory("R2EToken");
  const token = await Token.deploy();
  await token.waitForDeployment();
  console.log("✅ R2EToken deployed at:", await token.getAddress());

  const NFT = await hre.ethers.getContractFactory("RunnerNFT");
  const nft = await NFT.deploy();
  await nft.waitForDeployment();
  console.log("🏃 RunnerNFT deployed at:", await nft.getAddress());
}

main().catch(console.error);
