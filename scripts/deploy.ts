import { ethers } from "hardhat";

async function main() {
  const ALEO = await ethers.deployContract("contracts/Token.sol:ALEO");

  await ALEO.waitForDeployment();

  console.log(`Deploy contract to address ${ALEO.target}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});