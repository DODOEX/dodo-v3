import * as dotenv from 'dotenv';
dotenv.config();
import { readFileSync } from 'fs';
import * as toml from 'toml';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-gas-reporter';
import { HardhatUserConfig, subtask } from 'hardhat/config';
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names';
import "hardhat-deploy";
import "hardhat-preprocessor"
import 'solidity-docgen';

// default values here to avoid failures when running hardhat
const RINKEBY_RPC = process.env.RINKEBY_RPC || '1'.repeat(32);
const PRIVATE_KEY = process.env.PRIVATE_KEY || '1'.repeat(64);
const TRUFFLE_DASHBOARD_RPC = "http://localhost:24012/rpc";
const SOLC_DEFAULT = '0.8.16';

// try use forge config
let foundry: any;
try {
  foundry = toml.parse(readFileSync('./foundry.toml').toString());
  foundry.default.solc = foundry.default['solc-version']
    ? foundry.default['solc-version']
    : SOLC_DEFAULT;
} catch (error) {
  foundry = {
    default: {
      solc: SOLC_DEFAULT,
    }
  }
}

// prune forge style tests from hardhat paths
subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS)
  .setAction(async (_, __, runSuper) => {
    const paths = await runSuper();
    return paths.filter((p: string) => !p.endsWith('.t.sol'));
  });

const config: HardhatUserConfig = {
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  paths: {
    cache: 'cache-hardhat',
    sources: './contracts',
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: { chainId: 1337 },
    rinkeby: {
      url: RINKEBY_RPC,
      accounts: [PRIVATE_KEY],
    },
    goerli: {
      url: TRUFFLE_DASHBOARD_RPC,
      chainId: 5,
      deploy: ["./deploy/goerli/"],
    },
    arbitrum: {
      url: TRUFFLE_DASHBOARD_RPC,
      chainId: 42161,
      deploy: ["./deploy/arbitrum/"],
    },
    polygon: {
      url: TRUFFLE_DASHBOARD_RPC,
      chainId: 137,
      deploy: ["./deploy/polygon/"],
    },
    eth: {
      url: TRUFFLE_DASHBOARD_RPC,
      chainId: 1,
      deploy: ["./deploy/eth/"],
    },
    bsc: {
      url: TRUFFLE_DASHBOARD_RPC,
      chainId: 56,
      deploy: ["./deploy/bsc/"],
    },
    avax: {
      url: TRUFFLE_DASHBOARD_RPC,
      chainId: 43114,
      deploy: ["./deploy/avax/"],
    },
    op: {
      url: TRUFFLE_DASHBOARD_RPC,
      chainId: 10,
      deploy: ["./deploy/op/"],
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  solidity: {
    version: foundry.default?.solc || SOLC_DEFAULT,
    settings: {
      optimizer: {
        enabled: foundry.default?.optimizer || true,
        runs: foundry.default?.optimizer_runs || 200,
      },
    },
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 77,
    excludeContracts: ['src/test'],
    // API key for CoinMarketCap. https://pro.coinmarketcap.com/signup
    coinmarketcap: process.env.CMC_KEY ?? '',
  },
  etherscan: {
    // API key for Etherscan. https://etherscan.io/
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY ?? '',
      eth: process.env.ETHERSCAN_API_KEY ?? '',
      bsc: process.env.BSCSCAN_API_KEY ?? '',
      arbi_testnet: process.env.ARBITRUM_TESTNET_API_KEY ?? '',
      goerli: process.env.GOERLI_API_KEY ?? '',
      kcc: process.env.KCC_API_KEY ?? '',
      arbitrumOne: process.env.ARBITRUM_API_KEY ?? '',
      polygon: process.env.POLYGON_API_KEY ?? '',
      avalanche: process.env.SNOWTRACE_API_KEY ?? '',
      optimisticEthereum: process.env.OPTIMISM_API_KEY ?? '',
    },
    customChains: [
      {
        network: "arbi_testnet",
        chainId: 421611,
        urls: {
          apiURL: "https://api-testnet.arbiscan.io/api",
          browserURL: "https://testnet.arbiscan.io/"
        }
      },
      {
        network: "goerli",
        chainId: 5,
        urls: {
          apiURL: "https://api-goerli.etherscan.io/api",
          browserURL: "https://goerli.etherscan.io/"
        }
      },
      {
        network: "kcc",
        chainId: 321,
        urls: {
          apiURL: "https://api.explorer.kcc.io/vipapi",
          browserURL: "https://explorer.kcc.io/"
        }
      }
    ]
  },
  docgen: {
    pages: 'files',
    exclude: ['intf', 'lib', 'mock'],
    templates: './templates'
  },
};

function getRemappings() {
  return readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

export default config;
