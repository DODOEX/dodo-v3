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
    await deployD3Oracle(false);
    await deployD3RateManager(false);
    await deployFeeRateModel();
    await deployLiquidatorAdapter();
    await deployD3PoolQuota();
    await deployD3Vault(false);
    await depolyD3MMFactory();
    await deployD3Proxy();
    await deployD3UserQuota();
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

  async function deployD3Oracle(shouldSet: boolean) {
    const oracleAddress = await deployContract("D3Oracle", "D3Oracle", []);
    if (shouldSet) {
      const D3Oracle = await ethers.getContractAt("D3Oracle", oracleAddress);
      sleep(10)
      const priceSourceBTC = {
        oracle: config.chainlinkPriceFeed.BTCUSD,
        isWhitelisted: true,
        priceTolerance: BigNumber.from(padZeros(9, 17)),
        priceDecimal: 8,
        tokenDecimal: 8,
        heartBeat: 100000
      }
      console.log("setPrciceSource for WBTC...")
      await D3Oracle.setPriceSource(config.deployedAddress.wbtcAddress, priceSourceBTC);
      
      sleep(10)
      const priceSourceETH = {
        oracle: config.chainlinkPriceFeed.ETHUSD,
        isWhitelisted: true,
        priceTolerance: BigNumber.from(padZeros(9, 17)),
        priceDecimal: 8,
        tokenDecimal: 18,
        heartBeat: 100000
      }
      console.log("setPrciceSource for WETH...")
      await D3Oracle.setPriceSource(config.deployedAddress.wethAddress, priceSourceETH);
      
      sleep(10)
      const priceSourceDAI = {
        oracle: config.chainlinkPriceFeed.DAIUSD,
        isWhitelisted: true,
        priceTolerance: BigNumber.from(padZeros(9, 17)),
        priceDecimal: 8,
        tokenDecimal: 18,
        heartBeat: 100000
      }
      console.log("setPrciceSource for DAI...")
      await D3Oracle.setPriceSource(config.deployedAddress.daiAddress, priceSourceDAI);

      const priceSourceUSDT = {
        oracle: config.chainlinkPriceFeed.USDTUSD,
        isWhitelisted: true,
        priceTolerance: BigNumber.from(padZeros(9, 17)),
        priceDecimal: 8,
        tokenDecimal: 6,
        heartBeat: 100000
      }
      console.log("setPrciceSource for USDT...")
      await D3Oracle.setPriceSource(config.defaultAddress.USDT, priceSourceUSDT);

      const priceSourceUSDC = {
        oracle: config.chainlinkPriceFeed.USDCUSD,
        isWhitelisted: true,
        priceTolerance: BigNumber.from(padZeros(9, 17)),
        priceDecimal: 8,
        tokenDecimal: 6,
        heartBeat: 100000
      }
      console.log("setPrciceSource for USDC...")
      await D3Oracle.setPriceSource(config.defaultAddress.USDC, priceSourceUSDC);

      const priceSourceUSDCe = {
        oracle: config.chainlinkPriceFeed.USDCUSD,
        isWhitelisted: true,
        priceTolerance: BigNumber.from(padZeros(9, 17)),
        priceDecimal: 8,
        tokenDecimal: 6,
        heartBeat: 100000
      }
      console.log("setPrciceSource for USDCe...")
      await D3Oracle.setPriceSource(config.defaultAddress.USDCe, priceSourceUSDCe);
      
      sleep(10)
      const priceSourceDODO = {
        oracle: config.chainlinkPriceFeed.DODOUSD,
        isWhitelisted: true,
        priceTolerance: BigNumber.from(padZeros(9, 17)),
        priceDecimal: 8,
        tokenDecimal: 18,
        heartBeat: 100000
      }
      console.log("setPrciceSource for DODO...")
      await D3Oracle.setPriceSource(config.deployedAddress.dodoAddress, priceSourceDODO);
    }
  }

  async function deployD3RateManager(shouldSet: boolean) {
    const rateManagerAddress = await deployContract("D3RateManager", "D3RateManager", []);
    if (shouldSet) {
      const D3RateManager = await ethers.getContractAt("D3RateManager", rateManagerAddress);
      
      console.log("setStableCurve for WBTC...")
      await D3RateManager.setStableCurve(config.deployedAddress.wbtcAddress, padZeros(2, 16), padZeros(10, 16), padZeros(50, 16), padZeros(80, 16));
      
      await sleep(10)
      
      console.log("setStableCurve for WETH...")
      await D3RateManager.setStableCurve(config.deployedAddress.wethAddress, padZeros(2, 16), padZeros(10, 16), padZeros(50, 16), padZeros(80, 16));
      
      await sleep(10)
      
      console.log("setStableCurve for DAI...")
      await D3RateManager.setStableCurve(config.deployedAddress.daiAddress, padZeros(2, 16), padZeros(10, 16), padZeros(50, 16), padZeros(80, 16));

      console.log("setStableCurve for USDT...")
      await D3RateManager.setStableCurve(config.defaultAddress.USDT, padZeros(2, 16), padZeros(10, 16), padZeros(50, 16), padZeros(80, 16));

      console.log("setStableCurve for USDC...")
      await D3RateManager.setStableCurve(config.defaultAddress.USDC, padZeros(2, 16), padZeros(10, 16), padZeros(50, 16), padZeros(80, 16));

      console.log("setStableCurve for USDCe...")
      await D3RateManager.setStableCurve(config.defaultAddress.USDCe, padZeros(2, 16), padZeros(10, 16), padZeros(50, 16), padZeros(80, 16));
      
      await sleep(10)
      
      console.log("setStableCurve for DODO...")
      await D3RateManager.setStableCurve(config.deployedAddress.dodoAddress, padZeros(2, 16), padZeros(10, 16), padZeros(50, 16), padZeros(80, 16));
    }
  }

  async function deployFeeRateModel() {
    await deployContract("FeeRateModel", "D3FeeRateModel");
  }

  async function deployLiquidatorAdapter() {
    await deployContract("D3MMLiquidationRouter", "D3MMLiquidationRouter", [config.defaultAddress.DODOApprove]);
  }

  async function deployD3PoolQuota() {
    await deployContract("D3PoolQuota", "D3PoolQuota", []);
  }

  async function deployD3Vault(shouldSet: boolean) {
    const vaultAddress = await deployContract("D3Vault", "D3Vault", []);
    const dTokenAddress = await deployContract("D3TokenTemplate", "D3Token")
    if (shouldSet) {
      const D3Vault = await ethers.getContractAt("D3Vault", vaultAddress);
      console.log("set CloneFactory address...")
      await D3Vault.setCloneFactory(config.deployedAddress.CloneFactory);
      console.log("set D3Token template...")
      await D3Vault.setDTokenTemplate(dTokenAddress);
      console.log("set D3Oracle address...")
      await D3Vault.setNewOracle(config.deployedAddress.D3Oracle);
      console.log("set D3PoolQuota address...")
      await D3Vault.setNewD3PoolQuota(config.deployedAddress.D3PoolQuota);
      console.log("set D3RateManager address...")
      await D3Vault.setNewRateManager(config.deployedAddress.D3RateManager);
      console.log("set maintainer address...")
      await D3Vault.setMaintainer(config.deployedAddress.Maintainer);
    }
  }

  async function depolyD3MMFactory() {
    const d3MMTemplate = await deployContract("D3MMTemplate", "D3MM", []);
    const d3MakerTemplate = await deployContract("D3MakerTemplate", "D3Maker", []);
    const cloneFactory = config.deployedAddress.CloneFactory;
    const d3Vault = config.deployedAddress.D3Vault;
    const oracle = config.deployedAddress.D3Oracle;
    const feeModel = config.deployedAddress.FeeRateModel;
    const maintainer = config.deployedAddress.Maintainer;

    const args = [
      deployer, 
      [d3MMTemplate],
      [d3MakerTemplate],
      cloneFactory, 
      d3Vault,
      oracle,
      feeModel,
      maintainer 
    ];
    const d3MMFactory = await deployContract("D3MMFactory", "D3MMFactory", args);
    await verifyContract(d3MMFactory, args)
  }

  async function deployD3Proxy() {
    const vault = config.deployedAddress.D3Vault
    console.log("vault", vault)
    const dodoApproveProxy = config.defaultAddress.DODOApproveProxy
    console.log("approve proxy", dodoApproveProxy)
    const weth = config.defaultAddress.wethAddress
    console.log("weth", weth)
    await deployContract("D3Proxy", "D3Proxy", [dodoApproveProxy, weth, vault])
  }

  async function deployD3UserQuota() {
    const dodo = config.deployedAddress.dodoAddress
    const vault = config.deployedAddress.D3Vault
    await deployContract("D3UserQuota", "D3UserQuota", [dodo, vault])
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