import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import "@nomicfoundation/hardhat-ignition";
import * as dotenv from "dotenv";

dotenv.config();

const {
  SEPOLIA_RPC_URL,
  MAINNET_RPC_URL,
  SEPOLIA_PRIVATE_KEY,
  MAINNET_PRIVATE_KEY,
  ETHERSCAN_API_KEY,
  REPORT_GAS,
} = process.env;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {},
    sepolia: {
      url: SEPOLIA_RPC_URL || "",
      accounts: SEPOLIA_PRIVATE_KEY ? [`0x${SEPOLIA_PRIVATE_KEY}`] : [],
    },
    mainnet: {
      url: MAINNET_RPC_URL || "",
      accounts: MAINNET_PRIVATE_KEY ? [`0x${MAINNET_PRIVATE_KEY}`] : [],
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY || "",
  },
  gasReporter: {
    enabled: REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
};

export default config;
