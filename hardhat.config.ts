import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          metadata: {
            // Not including the metadata hash
            // https://github.com/paulrberg/hardhat-template/issues/31
            bytecodeHash: "none",
          },
          // Disable the optimizer when debugging
          // https://hardhat.org/hardhat-network/#solidity-optimizer-support
          optimizer: {enabled: true, runs: 10000},
          viaIR: true
        },
      },
    ],
  },
  etherscan: {
    apiKey: {
      "mirai": "mirai",
      'bscTestnet': "9ISBA776JT1N1NIXP9WGW6WN61J9DN1U3X",
    },
    customChains: [
      {
        network: "mirai",
        chainId: 2195,
        urls: {
          apiURL: "https://verify.miraiscan.io/v1/contract",
          browserURL: "https://miraiscan.io",
        }
      }
    ]
  },
  networks: {
    'mirai': {
      url: "https://rpc1-testnet.miraichain.io/",
      accounts: ["9705748f979b7e3a4aa3f06dff490f93cc754d460328c62b264f497aa89e8d03"],
    },

    'bscTestnet': {
      url: "https://bsc-testnet.blockpi.network/v1/rpc/public	",
      accounts: ["9705748f979b7e3a4aa3f06dff490f93cc754d460328c62b264f497aa89e8d03"],
    }
  },
};

export default config;