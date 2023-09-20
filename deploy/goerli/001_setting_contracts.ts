import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { GOERLI_CONFIG as config } from "../../config/goerli-config";
import { BigNumber } from "@ethersproject/bignumber";
import * as dotenv from 'dotenv';
dotenv.config();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // await main();

  async function main() {
    await setD3Vault(false)
  }

  async function setD3Vault(shouldSet: boolean) {
    const vaultAddress = config.deployedAddress.D3Vault
    if (shouldSet) {
      const D3Vault = await ethers.getContractAt("D3Vault", vaultAddress)
      console.log("set D3UserQuota address...")
      await D3Vault.setNewD3UserQuota(config.deployedAddress.D3UserQuota)
      console.log("set IM...")
      await D3Vault.setIM(bignumberFromE(40e16))
      console.log("set MM...")
      await D3Vault.setMM(bignumberFromE(20e16))
      console.log("add liquidation router...")
      await D3Vault.addRouter(config.deployedAddress.D3MMLiquidationRouter)

      console.log("set D3Factory...")
      await D3Vault.setNewD3Factory(config.deployedAddress.D3MMFactory)

      console.log("addNewToken WBTC...")
      await D3Vault.addNewToken(
        config.deployedAddress.wbtcAddress,
        bignumberFromE(1000e8),
        bignumberFromE(100e8),
        bignumberFromE(80e16),
        bignumberFromE(120e16),
        bignumberFromE(20e16)
      )

      console.log("addNewToken WETH...")
      await D3Vault.addNewToken(
        config.deployedAddress.wethAddress,
        bignumberFromE(1000e18),
        bignumberFromE(500e18),
        bignumberFromE(90e16),
        bignumberFromE(110e16),
        bignumberFromE(10e16)
      )

      console.log("addNewToken DAI...")
      await D3Vault.addNewToken(
        config.deployedAddress.daiAddress,
        bignumberFromE(1000e18),
        bignumberFromE(500e18),
        bignumberFromE(90e16),
        bignumberFromE(110e16),
        bignumberFromE(10e16)
      )

      console.log("addNewToken DODO...")
      await D3Vault.addNewToken(
        config.deployedAddress.dodoAddress,
        bignumberFromE(1000e18),
        bignumberFromE(500e18),
        bignumberFromE(90e16),
        bignumberFromE(110e16),
        bignumberFromE(10e16)
      )
    }
  }

  // ---------- helper function ----------
  function bignumberFromE(num) {
    let s = String(num)
    if (/\d+\.?\d*e[\+\-]*\d+/i.test(s)) {
      let parts = s.split('e')
      console.log('parts', parts)
      let r = parts[0]
      let l = Math.abs(parts.pop())
      let combine = r + new Array(l + 1).join('0')
      console.log(combine)
      return BigNumber.from(combine);
    } else {
      return BigNumber.from(String(num));
    }
  }

  function padZeros(origin: number, count: number) {
    return origin.toString() + '0'.repeat(count);
  }

  function sleep(s) {
    return new Promise(resolve => setTimeout(resolve, s * 1000));
  }
};

export default func;
func.tags = ["MockERC20"];
