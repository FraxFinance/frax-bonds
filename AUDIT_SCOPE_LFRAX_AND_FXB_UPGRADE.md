# Audit Scope for LFRAX and the FXB Upgrade
## LFRAX
LFRAX, or Legacy Frax Dollar, is the original stablecoin launched by Frax in 2020. It is backed by other fiatcoins, decentralized stablecoins, volatile tokens, and collateralized debt positions (Fraxlend). We are phasing it out in favor of our new stablecoin, frxUSD, which is only backed by cash and cash-like instruments. On Ethereum, LFRAX it is at [0x853d955acef822db058eb8505911ed77f175b99e](https://etherscan.io/token/0x853d955acef822db058eb8505911ed77f175b99e) and on Fraxtal, our L2 Optimism fork, it is at [0xff000000000000000000000000000000000001Fd](https://fraxscan.com/address/0xff000000000000000000000000000000000001Fd). On Fraxtal, its implementation is an OptimismMintablePermitERC20 that was factoried from an OptimismMintableERC20Factory (0x17FdBAdAc06C76C73Ea73b834341b02779C36AA0). 0xff...1fd is a proxy for that.

### LFRAX Audit Scope
The underlying OptimismMintablePermitERC20 and OptimismMintableERC20Factory code is well-established and does not need to be audited. I would just check that the proxy is set up properly. We were able to test the bridge successfully:

#### ETH -> Fraxtal
Send: https://etherscan.io/tx/0x1d72ddc524f099da2ce1573fb61769119689cf5278fd58452629616055305491
Receive: https://fraxscan.com/tx/0x6ee4827099d4df93a74fba4f046e554520e636c332209b472a305b68ee4bed1f

#### Fraxtal -> ETH
Send: https://fraxscan.com/tx/0x9f350efe74a46ba65fb70353b7958e7c05d434347ef537fd8c797dd783193e76
Prove: ???
Receive: ???

## FXB Upgrade
FXB (Frax Bonds) are zero-coupon bonds auctioned at less than 1 stablecoin and are redeemable for 1 stablecoin at maturity. As part of the current contract design, each FXB contract has 1:1 stablecoins "pre-loaded" in the contract, essentially sitting there doing nothing. For LFRAX, this is not really an issue for accounting purposes. However, for frxUSD, it is an issue because, per current GENIUS Act draft stipulations, we cannot have unbacked stablecoins. On Ethereum (example [FXB_4_DEC312026](https://etherscan.io/token/0x76237BCfDbe8e06FB774663add96216961df4ff3)), LFRAX is in each bond contract, but on Fraxtal, it is frxUSD instead (it was LFRAX originally, but we did a token upgrade converting LFRAX to frxUSD on Fraxtal only, not realizing this problem that would occur later on). So for each FXB on Fraxtal, we need to:
- Upgrade the contract
- In the initialization call, drain out the frxUSD, then burn it
- Set the redemption token to LFRAX (0xff000000000000000000000000000000000001Fd)
- Make sure allowances, permits, etc were not disrupted
- Make sure no new bugs were introduced
- Make sure other functions like redeeming work
- Right before maturity, we need to manually refill it 1:1 with LFRAX to match the FXB totalSupply

### FXB Upgrade Audit Scope
There are 4 FXBs that need to be upgraded:

| FXB    | Address |
| -------- | ------- |
| FXB20251231  | 0xacA9A33698cF96413A40A4eB9E87906ff40fC6CA |
| FXB20271231 | 0x6c9f4E6089c8890AfEE2bcBA364C2712f88fA818 |
| FXB20291231 | 0xF1e2b576aF4C6a7eE966b14C810b772391e92153 |
| FXB20551231 | 0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83 |

**New Implementation**  
src/contracts/FXB_LFRAX.sol

**Upgrade Gnosis Safe Scripts**  
src/script/LFRAX_FXB_Upgrade/00_DeployImpls.s.sol  
src/script/LFRAX_FXB_Upgrade/01_HandleNewLFRAX.s.sol  
src/script/LFRAX_FXB_Upgrade/02_UpgradeFXBs.s.sol  

**Tests**  
src/test/BaseTest_FXB_LFRAX.t.sol  
src/test/LFRAX_Upgrade_Test.t.sol  

