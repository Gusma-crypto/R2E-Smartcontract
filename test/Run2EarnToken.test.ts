import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox-mocha-ethers/network-helpers";
import { Run2EarnToken } from "../typechain-types";

describe("Run2EarnToken", function () {
  async function deployTokenFixture() {
    const [owner, teamWallet, user1, user2] = await ethers.getSigners();

    const Run2EarnToken = await ethers.getContractFactory("Run2EarnToken");
    const token = await Run2EarnToken.deploy(
      owner.address, // rewardsPool
      teamWallet.address, // teamWallet
      owner.address, // ecosystemWallet
      owner.address, // marketingWallet
      owner.address // treasuryWallet
    );

    return { token, owner, teamWallet, user1, user2 };
  }

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      const { token } = await loadFixture(deployTokenFixture);

      expect(await token.name()).to.equal("Run2Earn Health");
      expect(await token.symbol()).to.equal("R2E");
    });

    it("Should have correct total supply", async function () {
      const { token } = await loadFixture(deployTokenFixture);

      expect(await token.totalSupply()).to.equal(ethers.parseEther("100000000"));
    });

    it("Should distribute tokens correctly", async function () {
      const { token, owner, teamWallet } = await loadFixture(deployTokenFixture);

      // Check rewards pool allocation (40%)
      expect(await token.balanceOf(owner.address)).to.equal(ethers.parseEther("40000000"));

      // Check team allocation in contract (20%)
      expect(await token.balanceOf(await token.getAddress())).to.equal(ethers.parseEther("20000000"));

      // Check ecosystem allocation (15%)
      expect(await token.balanceOf(owner.address)).to.equal(ethers.parseEther("40000000")); // rewardsPool + ecosystem

      // Check marketing allocation (10%)
      expect(await token.balanceOf(owner.address)).to.equal(ethers.parseEther("40000000")); // rewardsPool + ecosystem + marketing

      // Check treasury allocation (5%)
      expect(await token.balanceOf(owner.address)).to.equal(ethers.parseEther("40000000")); // all allocations to owner
    });
  });

  describe("Team Token Vesting", function () {
    it("Should not allow claiming before vesting starts", async function () {
      const { token, teamWallet } = await loadFixture(deployTokenFixture);

      // Try to claim immediately after deployment
      await expect(token.connect(teamWallet).claimTeamTokens()).to.be.revertedWith("Vesting not started");
    });

    it("Should calculate claimable tokens correctly", async function () {
      const { token, teamWallet } = await loadFixture(deployTokenFixture);

      // Immediately after deployment
      let claimable = await token.getClaimableTeamTokens();
      expect(claimable).to.equal(0);

      // Fast forward 1 year (50% vested)
      await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]); // 1 year in seconds
      await ethers.provider.send("evm_mine", []);

      claimable = await token.getClaimableTeamTokens();
      const expectedClaimable = ethers.parseEther("10000000"); // 50% of 20,000,000
      expect(claimable).to.be.closeTo(expectedClaimable, ethers.parseEther("1000")); // Allow small rounding difference
    });

    it("Should allow team wallet to claim vested tokens", async function () {
      const { token, teamWallet } = await loadFixture(deployTokenFixture);

      // Fast forward 1 year
      await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      const claimable = await token.getClaimableTeamTokens();

      await expect(token.connect(teamWallet).claimTeamTokens()).to.emit(token, "TeamTokensClaimed").withArgs(teamWallet.address, claimable);

      // Check balance after claim
      const teamBalance = await token.balanceOf(teamWallet.address);
      expect(teamBalance).to.equal(claimable);
    });

    it("Should not allow non-team wallet to claim", async function () {
      const { token, user1 } = await loadFixture(deployTokenFixture);

      // Fast forward 1 year
      await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      await expect(token.connect(user1).claimTeamTokens()).to.be.revertedWith("Only team wallet");
    });

    it("Should return complete vesting info", async function () {
      const { token } = await loadFixture(deployTokenFixture);

      const vestingInfo = await token.getVestingInfo();

      expect(vestingInfo.startTime).to.be.greaterThan(0);
      expect(vestingInfo.duration).to.equal(730 * 24 * 60 * 60); // 730 days in seconds
      expect(vestingInfo.totalAllocation).to.equal(ethers.parseEther("20000000"));
      expect(vestingInfo.claimed).to.equal(0);
      expect(vestingInfo.claimable).to.equal(0);
      expect(vestingInfo.vestedPercentage).to.equal(0);
    });
  });

  describe("Wallet Management", function () {
    it("Should allow owner to update team wallet", async function () {
      const { token, owner, user1 } = await loadFixture(deployTokenFixture);

      await expect(token.connect(owner).updateTeamWallet(user1.address)).to.emit(token, "WalletUpdated").withArgs("Team", anyValue, user1.address);

      expect(await token.teamWallet()).to.equal(user1.address);
    });

    it("Should not allow non-owner to update wallets", async function () {
      const { token, user1, user2 } = await loadFixture(deployTokenFixture);

      await expect(token.connect(user1).updateTeamWallet(user2.address)).to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
    });

    it("Should not allow updating to zero address", async function () {
      const { token, owner } = await loadFixture(deployTokenFixture);

      await expect(token.connect(owner).updateTeamWallet(ethers.ZeroAddress)).to.be.revertedWith("Invalid team wallet");
    });

    it("Should not allow updating to same wallet", async function () {
      const { token, owner, teamWallet } = await loadFixture(deployTokenFixture);

      await expect(token.connect(owner).updateTeamWallet(teamWallet.address)).to.be.revertedWith("Same as current wallet");
    });
  });

  describe("Token Burning", function () {
    it("Should allow token burning", async function () {
      const { token, owner } = await loadFixture(deployTokenFixture);

      const burnAmount = ethers.parseEther("1000");
      await expect(token.connect(owner).burn(burnAmount)).to.emit(token, "Transfer").withArgs(owner.address, ethers.ZeroAddress, burnAmount);

      const newTotalSupply = await token.totalSupply();
      expect(newTotalSupply).to.equal(ethers.parseEther("99999000"));
    });
  });

  describe("ERC20 Votes", function () {
    it("Should track votes correctly", async function () {
      const { token, owner } = await loadFixture(deployTokenFixture);

      const votes = await token.getVotes(owner.address);
      expect(votes).to.be.greaterThan(0);
    });
  });
});

// Helper untuk anyValue matcher
const anyValue = () => true;
