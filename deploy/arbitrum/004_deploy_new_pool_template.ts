import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ARBITRUM_CONFIG as config } from "../../config/arbitrum-config";
import { BigNumber } from "@ethersproject/bignumber";
import * as dotenv from 'dotenv';
dotenv.config();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // await main();

  async function main() {
    const d3MMTemplate = await deployContract("D3MMTemplate", "D3MM", []);
    const d3MakerTemplate = await deployContract("D3MakerTemplate", "D3Maker", []);
    console.log("new D3MM template:", d3MMTemplate)
    console.log("new D3Maker template:", d3MakerTemplate)
  }

  async function deployContract(name: string, contract: string, args?: any[]) {
    if (typeof args == 'undefined') {
      args = []
    }
    if (!config.deployedAddress[name] || config.deployedAddress[name] == "") {
      console.log("Deploying contract:", name);
      const deployResult = await deploy(contract, {
        from: deployer,
        args: args,
        log: true,
      });
      await verifyContract(deployResult.address, args);
      return deployResult.address;
    } else {
      console.log("Fetch previous deployed address for", name, config.deployedAddress[name]);
      return config.deployedAddress[name];
    }
  }

  async function verifyContract(address: string, args?: any[]) {
    if (typeof args == 'undefined') {
      args = []
    }
    try {
      await hre.run("verify:verify", {
        address: address,
        constructorArguments: args,
      });
    } catch (e) {
      if (e.message != "Contract source code already verified") {
        throw(e)
      }
      console.log(e.message)
    }
  }

  // ---------- helper function ----------

  function padZeros(origin: number, count: number) {
    return origin.toString() + '0'.repeat(count);
  }

  function sleep(s) {
    return new Promise(resolve => setTimeout(resolve, s * 1000));
  }
};

export default func;