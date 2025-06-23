# FXB UPGRADE WALKTHROUGH (UPGRADE PART ONLY, NOT CARTER'S V2 PART FOR NEWLY FACTORIED FXBS GOING FORWARD)

## TL;DR
### Explain the main features of the system, e.g., main functionality, fee mechanisms, trust model
A general overview of the FXB system is here [here](https://docs.frax.com/protocol/assets/frxusd/fxb)
### Explain which smart contract of the system is responsible for each implemented feature
src/contracts/FXB_LFRAX.sol will be the new impl. src/contracts/FXB.sol is the old (and currently, live) one.
All the bond features are self-contained on each contract. Creation of new ones / factory-ing is in Carter's V2 part.
The FXBs have ERC20/Permit functionality 
### Explain interactions within smart contracts of the system
See the audit scope for a definition of LFRAX (Legacy Frax Dollar).

FXB (Frax Bonds) are zero-coupon bonds auctioned at less than 1 stablecoin and are redeemable for 1 stablecoin at maturity. As part of the current contract design, each FXB contract has 1:1 stablecoins "pre-loaded" in the contract, essentially sitting there doing nothing. For LFRAX, this is not really an issue for accounting purposes. However, for frxUSD, it is an issue because, per current GENIUS Act draft stipulations, we cannot have unbacked stablecoins. On Ethereum (example [FXB_4_DEC312026](https://etherscan.io/token/0x76237BCfDbe8e06FB774663add96216961df4ff3)), LFRAX is in each bond contract, but on Fraxtal, it is frxUSD instead (it was LFRAX originally, but we did a token upgrade converting LFRAX to frxUSD on Fraxtal only, not realizing this problem that would occur later on).

For accounting / liquidity purposes, users can still mint bonds 1:1 with underlying before (or after) maturity, but they cannot redeem it until after maturity. This route is also used by the Slippage Auction / Factory when it is preparing a bond tranche to sell.

### Explain integrations with external systems (e.g., Uniswap)
LFRAX is moved to/from the contract during mint/redeems respectively. No external DEXs/oracles/etc are used.

## Conceptual idea
### Give us a high-level explanation of what the product achieves.
### Give us a high-level explanation of how it does that.
See above mostly. The FXB ERC20 itself is fairly simple. The Slippage Auction mechanism (Carter's section) is probably the more vulnerable part to exploit (e.g. someone finding out a way to get super-cheap bonds below expected price thresholds/limits). Or a flaw in the FraxBeacon and/or normal proxy setups.
### Explain non-trivial financial logic, math, or similar.
See code commentary and natspec
### Feel free to elaborate on important system parameters.
N/A


## Actors and trust model
### What are the different roles in your system?
### What are the trust assumptions between them?
The ProxyAdmin can upgrade the contract, and the FXBFactory.timelockAddress() can burn bonds early. Other than that, there are no higher level permissions beyond that for ERC20s.
### What assumptions do you make about external systems?
N/A
### If there are any admin roles, what are they allowed to do?
See above
### Are there off-chain components and what do they do?
N/A

## Architectural overview
### What smart contracts will be deployed? Are there any proxies?
For each FXB on Fraxtal, we need to:
- Upgrade the contract
- In the initialization call, drain out the frxUSD, then burn it
- Set the redemption token to LFRAX (0xff000000000000000000000000000000000001Fd)
- Before maturity, our team will directly transfer LFRAX to the FXB contract matching its' totalSupply 1:1, enabling full redemption

When we first launched FXBs v1 on Fraxtal, the contracts were fixed and immutable and are currently backed by frxUSD (referenced as "FRAX" in the contracts) (see original FXBFactory and FXB [here](https://github.com/FraxFinance/frax-bonds/tree/6910116b1eb7864a4dfed14c5224a4ceb0f26eed)). If you look at one of the deployed FXBs today ([example](https://fraxscan.com/address/0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83#code)), you'll see it is behind a proxy.  How did we change the production immutable contracts?  We overwrote the immutable FXB contracts in a hardfork to be proxies, pointing to the same [implementation](https://fraxscan.com/address/0xfcc0d376af4c6a7ee966b14c810b772391e92153).  These proxies are what will be upgraded.
### Where are the different users supposed to enter the system?
Through the Slippage Auction or buying the FXBs on a DEX
### How are the system’s smart contracts supposed to interact with each other?
N/A
### How are third-party systems integrated into your system design (integrations) and what do these systems roughly do (if we are unfamiliar with them)?
N/A
### Different codebases have different coding styles, give us a short brief from the software engineer’s perspective on how the code is structured.
I tried to inherit and annotate/comment where I could. State vars, then constructor / initialization, then EIP712 / ERC20Permit overrides, view functions, public functions, then errors.
### Please tell us your concerns and which parts of the system are the most complex.
As mentioned previously, after the upgrade,
- Make sure allowances, permits, etc were not disrupted
- Make sure storage slots match or are not negatively affected
- Make sure no new bugs were introduced
- Make sure other functions like redeeming work
- Make sure the proxies are set up correctly
- Make sure people cannot redeem early
