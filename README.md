# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```
## Start project
Need to specific `UniswapV2Router02` address in `Utils.sol`. In this case, we use `0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506` for BSC testnet.
### Deploy:
```typescript 
npx hardhat run scripts/deploy.ts --network bscTestnet
 ```
It will return the deployed address. use this address to verify in block explorer.
### Verify 
```typescript
npx hardhat verify --contract "contracts/Token.sol:ALEO"  --network bscTestnet 0xae5Efa0D8c2D22e00De1cC7Fe519A0f599751e64
```
In this case, we use `0xae5Efa0D8c2D22e00De1cC7Fe519A0f599751e64` as deployed address. 