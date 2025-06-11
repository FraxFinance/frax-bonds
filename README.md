# FXB
## Author: Frax.Finance

## Basic Description
### FXB
A `FXB` is a basic ERC20 token that can be created by the Frax AMO [Timelock](https://etherscan.io/address/0x831822660572bd54ebaa065C2acef662a6277D40/).  Each FXB contains a unique [maturity](https://capital.com/bond-maturity-definition) which always expires on a Wednesday, UTC 00:00.

After a FXB is created, anyone is able to mint the FXB by depositing FRAX.  For every unit of FRAX deposited, the depositor receives the equivalent amount of FXB.  After the current time has passed the maturity timestamp, any FXB holder of that specific maturity is able to redeem the equivalent FRAX by returning the FXB.

### FXBFactory ([etherscan](https://etherscan.io/address/0x7a07D606c87b7251c2953A30Fa445d8c5F856C7A#code))
Factory contract permissioned to Frax [Timelock](https://etherscan.io/address/0x831822660572bd54ebaa065C2acef662a6277D40/) to create a FXB.

### SlippageAuction
A `SlippageAuction` operates similarly to a [Uniswap V2 Pair](https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol) with different mathematics and additional functionality.  A caller can utilize the `swap()` method similarly and plug the SlippageAuction into a router.

There is an owner of the SlippageAuction who has permissions to:
- Start an auction
    - The buy/sell token must be `token0`, `token1` respectively
    - Have any auction configuration meeting basic requirements
- Stop an auction
    - Returns all token0, token1 held by the auction contract to the owner
    - Can be done at any time
- Transfer auction ownership

Every SlippageAuction runs one auction at a time using a continuous Gradual Dutch Auction, as described by [Paradigm](https://www.paradigm.xyz/2022/04/gda).  The mechanics work like so:
- Owner starts an auction with:
    - Amount of tokens to sell
    - Starting Price
    - Minimum Allowed Price
    - Price Decay
    - Slippage
    - Expiration
- As time passes, the price to purchase the tokens decreases linearly due to the set Price Decay.
- If someone buys the tokens, the amount they swap has slippage due to the set Slippage.
- After a swap, the price of tokens increases by twice the Slippage.
- Swappers can only ever swap token0 (buyToken) for token1 (sellToken).
- Price can never go below the MinimumAllowedPrice, before Slippage.

### SlippageAuctionFactory ([etherscan](https://etherscan.io/address/0x983aF86c94Fe3963989c22CeeEb6eA8Eac32D263#code))
Permission-less factory contract to create a SlippageAuction.

### Additional Information
See the formal [documentation](https://docs.frax.finance/frax-v3/fxbs).

See current FXB [auctions](https://app.frax.finance/fxb/overview).

AuctionFactory deploy commit: [384f562](https://github.com/FraxFinance/dev-frax-bonds/pull/89/commits/384f562944a8c01bc4159c5f0ab695fa307bfb1e)

FXBFactory deploy commit: [5879a32](https://github.com/FraxFinance/dev-frax-bonds/commit/5879a321a5a9c697fa50aaed1b5e46d2d469cb83)

## Assumptions
- `swapTokensForExactTokens()`
    - Intended to be used with `getAmountIn()` and `getAmountInMax()`
    - Using `getAmountOut()` prior may revert due to precision rounding down
- `swapExactTokensForTokens()`
    - Intended to be used with `getAmountOut()`
    - Using `getAmountIn()` prior may revert due to precision rounding down
- `getAmountInMax()`
    - May revert when swapping when `amountInMax < 1e5` due to precision rounding down
- Output from chain-calling `getAmountIn()` and `getAmountOut()` may round down due to precision
- `startAuction()`
    - Assume that `params.amountListed > 1e8` to prevent rounding issues.  See minimums set in the fuzz tests for generally acceptable ranges.

## [Specification](./specification/README.md)

## Installation
`npm install`

## Compile
`forge build`

## Build docs
`forge doc`

## Test
`forge test`

## Deploy
- Ensure your solc version matches the version of the deployed scripts
- `cp .env.example .env` and update variables
- Update `FXB_TIMELOCK` and `FRAX_ERC20` in `scripts/constants/mainnet.ts` to pass into the `FXBFactory` constructor
- `npm run generate:constants`
- `source .env`
- `forge script src/script/DeployFxbFactory.s.sol --rpc-url mainnet --broadcast --verify -vvvv --slow`
- `forge script src/script/DeploySlippageAuctionFactory.s.sol --rpc-url mainnet --broadcast --verify -vvvv --slow`


## Tooling
This repo uses the following tools:
- frax-standard-solidity for testing and scripting helpers
- forge fmt & prettier for code formatting
- lint-staged & husky for pre-commit formatting checks
- solhint for code quality and style hints
- foundry for compiling, testing, and deploying
