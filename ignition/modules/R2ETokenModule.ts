// SPDX-License-Identifier: MIT
// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseUnits } from "viem";

const R2ETokenModule = buildModule("R2ETokenModule", (m) => {
  // 💰 Parameter konfigurasi
  const initialSupply = m.getParameter("initialSupply", 1_000_000n);
  const rewardPool = m.getParameter("rewardPool", 500_000n);
  const trustedSigner = m.getParameter("trustedSigner", m.getAccount(0));

  // 1️⃣ Deploy RunToken
  const runToken = m.contract("RunToken", [initialSupply]);

  // 2️⃣ Deploy RunToEarn dengan parameter token address & signer
  const r2etoken = m.contract("R2EToken", [runToken, trustedSigner]);

  // 3️⃣ Setelah deploy, transfer sebagian token ke kontrak RunToEarn
  m.call(runToken, "transfer", [r2etoken, parseUnits("500000", 18)]);

  // 📦 Kembalikan kontrak yang dideploy
  return { runToken, r2etoken };
});

export default R2ETokenModule;
