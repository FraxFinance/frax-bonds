# Audit Scope for LFRAX, FXBs, and the FXB Upgrade
## LFRAX
LFRAX, or Legacy Frax Dollar, is the original stablecoin launched by Frax in 2020. It is backed by other fiatcoins, decentralized stablecoins, volatile tokens, and collateralized debt positions (Fraxlend). We are phasing it out in favor of our new stablecoin, frxUSD, which is only backed by cash and cash-like instruments. On Ethereum, LFRAX it is at [0x853d955acef822db058eb8505911ed77f175b99e](https://etherscan.io/token/0x853d955acef822db058eb8505911ed77f175b99e) and on Fraxtal, our L2 Optimism fork, it is at [0xff000000000000000000000000000000000001Fd](https://fraxscan.com/address/0xff000000000000000000000000000000000001Fd). On Fraxtal, its implementation is an OptimismMintablePermitERC20 that was factoried from an OptimismMintableERC20Factory (0x17FdBAdAc06C76C73Ea73b834341b02779C36AA0). 0xff...1fd is a proxy for that.

### LFRAX Audit Scope
The underlying OptimismMintablePermitERC20 and OptimismMintableERC20Factory code is well-established and does not need to be audited. I would just check that the proxy is set up properly. We were able to test the bridge successfully:

#### ETH -> Fraxtal
Send: https://etherscan.io/tx/0x1d72ddc524f099da2ce1573fb61769119689cf5278fd58452629616055305491
Receive: https://fraxscan.com/tx/0x6ee4827099d4df93a74fba4f046e554520e636c332209b472a305b68ee4bed1f

#### Fraxtal -> ETH
Send: https://fraxscan.com/tx/0x9f350efe74a46ba65fb70353b7958e7c05d434347ef537fd8c797dd783193e76
Prove: https://etherscan.io/tx/0x7dda3ed0f2580113545cb45aa417db13039f2e235bf9840e451a26d6ddfdf230
Receive: https://etherscan.io/tx/0x526c5bf3c71a2b2d6c737c2b54e1234518d2714e0b19ff045df8b1c7eea1522a

## FXB Upgrade
FXB (Frax Bonds) are zero-coupon bonds auctioned at less than 1 stablecoin and are redeemable for 1 stablecoin at maturity. As part of the current contract design, each FXB contract has 1:1 stablecoins "pre-loaded" in the contract, essentially sitting there doing nothing. For LFRAX, this is not really an issue for accounting purposes. However, for frxUSD, it is an issue because, per current GENIUS Act draft stipulations, we cannot have unbacked stablecoins. On Ethereum (example [FXB_4_DEC312026](https://etherscan.io/token/0x76237BCfDbe8e06FB774663add96216961df4ff3)), LFRAX is in each bond contract, but on Fraxtal, it is frxUSD instead (it was LFRAX originally, but we did a token upgrade converting LFRAX to frxUSD on Fraxtal only, not realizing this problem that would occur later on).

For each FXB on Fraxtal, we need to:
- Upgrade the contract
- In the initialization call, drain out the frxUSD, then burn it
- Set the redemption token to LFRAX (0xff000000000000000000000000000000000001Fd)
- Make sure allowances, permits, etc were not disrupted
- Make sure no new bugs were introduced
- Make sure other functions like redeeming work
- Before maturity, our team will directly transfer LFRAX to the FXB contract matching its' totalSupply 1:1, enabling full redemption

When we first launched FXBs v1 on Fraxtal, the contracts were fixed and immutable and are currently backed by frxUSD (referenced as "FRAX" in the contracts) (see original FXBFactory and FXB [here](https://github.com/FraxFinance/frax-bonds/tree/6910116b1eb7864a4dfed14c5224a4ceb0f26eed)).  If you look at one of the deployed FXBs today ([example](https://fraxscan.com/address/0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83#code)), you'll see it is behind a proxy.  How did we change the production immutable contracts?  We overwrote the immutable FXB contracts in a hardfork to be proxies, pointing to the same [implementation](https://fraxscan.com/address/0xfcc0d376af4c6a7ee966b14c810b772391e92153).  These proxies are what will be upgraded.

### FXB Upgrade Audit Scope
There are 4 FXBs that need to be upgraded:

| FXB    | Address |
| -------- | ------- |
| FXB20251231  | 0xacA9A33698cF96413A40A4eB9E87906ff40fC6CA |
| FXB20271231 | 0x6c9f4E6089c8890AfEE2bcBA364C2712f88fA818 |
| FXB20291231 | 0xF1e2b576aF4C6a7eE966b14C810b772391e92153 |
| FXB20551231 | 0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83 |

**New Implementation**  
- `src/contracts/FXB_LFRAX.sol`

**Upgrade Gnosis Safe Scripts**
- `src/script/LFRAX_FXB_Upgrade/00_DeployImpls.s.sol`
- `src/script/LFRAX_FXB_Upgrade/01_HandleNewLFRAX.s.sol`
- `src/script/LFRAX_FXB_Upgrade/02_UpgradeFXBs.s.sol`

**Tests**
- `src/test/BaseTest_FXB_LFRAX.t.sol`  
- `src/test/LFRAX_Upgrade_Test.t.sol`

## FXB v2: Beacon FXBs

The existing FXB factory only creates more immutable FXBs, backed by frxUSD.  If we want to create a new FXB, there are two routes we could take to have a proxy FXB backed by LFRAX:
1. Use the existing FXB factory.  The steps would be as follows:
    1. Deploy immutable FXB backed by frxUSD
    1. Modify FXB bytecode to be a proxy in a hardfork
    1. Upgrade the FXB to be backed by LFRAX (see "FXB Upgrade")
1. Deploy a new FXB factory that creates proxy FXBs

We are going with (2).  The spec is as follows:
1. Upgradeable FXBFactory.  This contract is a simple transparent upgradeable proxy owned by the Frax team [ProxyAdmin](https://fraxscan.com/address/0xfc0000000000000000000000000000000000000a).
1. Upgradeable FXB. This contract is a beacon proxy that references a Beacon contract stored by the FXBFactory.
1. Beacon.  This contract stores the implementation address behind all newly deployed FXBs, owned by the Frax [msig](https://fraxscan.com/address/0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6).

### FXB v2 Audit Scope
- `src/contracts/FraxBeacon.sol`
- `src/contracts/FraxBeaconProxy.sol`
- `src/contracts/FraxUpgradeableProxy.sol`
- `src/contracts/FXB.sol`
- `src/contracts/FXBFactory.sol`
