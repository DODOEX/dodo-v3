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

  await main();

  async function main() {
    await createD3MM();
  }

  async function createD3MM() {
    const d = config.deployedAddress;
    const d3MMFactory = await ethers.getContractAt("D3MMFactory", config.deployedAddress.D3MMFactory);
    const d3MM = await d3MMFactory.breedD3Pool(
      deployer,
      deployer,
      24 * 3600,
      0
    )
    console.log("new D3MM:", d3MM);
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
