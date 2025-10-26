const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("R2EToken", function () {
  it("Should deploy and mint reward", async function () {
    const [owner, user] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("R2EToken");
    const token = await Token.deploy();

    await token.waitForDeployment();
    expect(await token.totalSupply()).to.equal(ethers.parseEther("100000000"));

    await token.mintReward(user.address, ethers.parseEther("10"));
    expect(await token.balanceOf(user.address)).to.equal(ethers.parseEther("10"));
  });
});
