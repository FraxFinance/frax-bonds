# SlippageAuction
[Git Source](https://github.com/fraxfinance/frax-bonds/blob/master/src/contracts/SlippageAuction.sol)

**Inherits:**
ReentrancyGuard, Timelock2Step

Slippage auction to sell tokens over time. Created via factory.

*Both tokens must be 18 decimals.*

*https://github.com/FraxFinance/frax-bonds*


## State Variables
### name
The name of this auction


```solidity
string public name;
```


### PRECISION
Slippage precision


```solidity
uint256 public constant PRECISION = 1e18;
```


### details
Stored information about details


```solidity
Detail[] public details;
```


### TOKEN_BUY
The token used for buying the tokenSell


```solidity
address public immutable TOKEN_BUY;
```


### TOKEN_SELL
The token being auctioned off


```solidity
address public immutable TOKEN_SELL;
```


### token0
Alias for TOKEN_BUY

*Maintains UniswapV2 interface*


```solidity
address public immutable token0;
```


### token1
Alias for TOKEN_SELL

Maintains UniswapV2 interface


```solidity
address public immutable token1;
```

## Structs
### Detail
Detail information behind an auction

Auction information


```solidity
struct Detail {
    uint128 amountListed;
    uint128 amountLeft;
    uint128 amountExcessBuy;
    uint128 amountExcessSell;
    uint128 tokenBuyReceived;
    uint128 priceLast;
    uint128 priceMin;
    uint64 priceDecay;
    uint64 priceSlippage;
    uint32 lastBuyTime;
    uint32 expiry;
    bool active;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`amountListed`|`uint128`|Amount of sellToken placed for auction|
|`amountLeft`|`uint128`|Amount of sellToken remaining to buy|
|`amountExcessBuy`|`uint128`|Amount of any additional TOKEN_BUY sent to contract during auction|
|`amountExcessSell`|`uint128`|Amount of any additional TOKEN_SELL sent to contract during auction|
|`tokenBuyReceived`|`uint128`|Amount of tokenBuy that came in from sales|
|`priceLast`|`uint128`|Price of the last sale, in tokenBuy amount per tokenSell (amount of tokenBuy to purchase 1e18 tokenSell)|
|`priceMin`|`uint128`|Minimum price of 1e18 tokenSell, in tokenBuy|
|`priceDecay`|`uint64`|Price decay, (wei per second), using PRECISION|
|`priceSlippage`|`uint64`|Slippage fraction. E.g (0.01 * PRECISION) = 1%|
|`lastBuyTime`|`uint32`|Time of the last sale|
|`expiry`|`uint32`|UNIX timestamp when the auction ends|
|`active`|`bool`|If the auction is active|

### StartAuctionParams
Parameters for starting an auction

*Sender must have an allowance on tokenSell*


```solidity
struct StartAuctionParams {
    uint128 amountListed;
    uint128 priceStart;
    uint128 priceMin;
    uint64 priceDecay;
    uint64 priceSlippage;
    uint32 expiry;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`amountListed`|`uint128`|Amount of tokenSell being sold|
|`priceStart`|`uint128`|Starting price of 1e18 tokenSell, in tokenBuy|
|`priceMin`|`uint128`|Minimum price of 1e18 tokenSell, in tokenBuy|
|`priceDecay`|`uint64`|Price decay, (wei per second), using PRECISION|
|`priceSlippage`|`uint64`|Slippage fraction. E.g (0.01 * PRECISION) = 1%|
|`expiry`|`uint32`|UNIX timestamp when the auction ends|



## Functions
### constructor


```solidity
constructor(address _timelock, address _tokenBuy, address _tokenSell) Timelock2Step(_timelock);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelock`|`address`|Address of the timelock/owner|
|`_tokenBuy`|`address`|Token used to purchase _tokenSell|
|`_tokenSell`|`address`|Token sold in the auction|


### version

Returns the semantic version of this contract


```solidity
function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_major`|`uint256`|The major version|
|`_minor`|`uint256`|The minor version|
|`_patch`|`uint256`|The patch version|


### getPreSlippagePrice

Calculates the pre-slippage price (with the user supplied auction _detail) from the time decay alone


```solidity
function getPreSlippagePrice(Detail memory _detail) public view returns (uint256 _price);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_detail`|`Detail`|The auction struct|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_price`|`uint256`|The price|


### getPreSlippagePrice

Calculates the pre-slippage price (with the current auction) from the time decay alone


```solidity
function getPreSlippagePrice() external view returns (uint256 _price);
```

### getAmountOut

Calculates the amount of tokenSells out for a given tokenBuy amount


```solidity
function getAmountOut(uint256 amountIn, bool _revertOnOverAmountLeft) public view returns (uint256 amountOut, uint256 _slippagePerTokenSell, uint256 _postPriceSlippage);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|Amount of tokenBuy in|
|`_revertOnOverAmountLeft`|`bool`|Whether to revert if amountOut > amountLeft|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountOut`|`uint256`|Amount of tokenSell out|
|`_slippagePerTokenSell`|`uint256`|The slippage component of the price change (in tokenBuy per tokenSell)|
|`_postPriceSlippage`|`uint256`|The post-slippage price from the time decay + slippage|


### getAmountInMax

Calculates how much tokenBuy you would need to buy out the remaining tokenSell in the auction


```solidity
function getAmountInMax() external view returns (uint256 amountIn, uint256 _slippagePerTokenSell, uint256 _postPriceSlippage);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|Amount of tokenBuy needed|
|`_slippagePerTokenSell`|`uint256`|The slippage component of the price change (in tokenBuy per tokenSell)|
|`_postPriceSlippage`|`uint256`|The post-slippage price from the time decay + slippage|


### getAmountIn

Calculates how much tokenBuy you would need in order to obtain a given number of tokenSell


```solidity
function getAmountIn(uint256 amountOut) public view returns (uint256 amountIn, uint256 _slippagePerTokenSell, uint256 _postPriceSlippage);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountOut`|`uint256`|The desired amount of tokenSell|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|Amount of tokenBuy needed|
|`_slippagePerTokenSell`|`uint256`|The slippage component of the price change (in tokenBuy per tokenSell)|
|`_postPriceSlippage`|`uint256`|The post-slippage price from the time decay + slippage|


### _getAmountIn

Calculate how much tokenBuy you would need to obtain a given number of tokenSell


```solidity
function _getAmountIn(Detail memory _detail, uint256 amountOut) internal view returns (uint256 amountIn, uint256 _slippagePerTokenSell, uint256 _postPriceSlippage);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_detail`|`Detail`|The auction struct|
|`amountOut`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|Amount of tokenBuy needed|
|`_slippagePerTokenSell`|`uint256`|The slippage component of the price change (in tokenBuy per tokenSell)|
|`_postPriceSlippage`|`uint256`|The post-slippage price from the time decay + slippage|


### getAmountIn

Calculates how much tokenBuy you would need in order to obtain a given number of tokenSell

*Maintains compatibility with some router implementations*


```solidity
function getAmountIn(uint256 amountOut, address tokenOut) public view returns (uint256 amountIn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountOut`|`uint256`|The amount out of sell tokens|
|`tokenOut`|`address`|The sell token address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|The amount of tokenBuy needed|


### getAmountOut

Calculates the amount of tokenSell out for a given tokenBuy amount

*Used to maintain compatibility*


```solidity
function getAmountOut(uint256 amountIn, address tokenIn) public view returns (uint256 amountOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|Amount of tokenBuy in|
|`tokenIn`|`address`|The token being swapped in|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountOut`|`uint256`|Amount of tokenSells out|


### skim

*Uni v2 support without revert*


```solidity
function skim(address) external pure;
```

### sync

*Uni v2 support without revert*


```solidity
function sync() external pure;
```

### getAmountOut


```solidity
function getAmountOut(uint256, uint256, uint256) external pure returns (uint256);
```

### getAmountIn


```solidity
function getAmountIn(uint256, uint256, uint256) external pure returns (uint256);
```

### getReserves


```solidity
function getReserves() external pure returns (uint112, uint112, uint32);
```

### price0CumulativeLast


```solidity
function price0CumulativeLast() external pure returns (uint256);
```

### price1CumulativeLast


```solidity
function price1CumulativeLast() external pure returns (uint256);
```

### kLast


```solidity
function kLast() external pure returns (uint256);
```

### factory


```solidity
function factory() external pure returns (address);
```

### MINIMUM_LIQUIDITY


```solidity
function MINIMUM_LIQUIDITY() external pure returns (uint256);
```

### initialize


```solidity
function initialize(address, address) external pure;
```

### getDetailStruct

Gets a struct instead of a tuple for details()


```solidity
function getDetailStruct(uint256 _auctionNumber) external view returns (Detail memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_auctionNumber`|`uint256`|Detail ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Detail`|The struct of the auction|


### detailsLength

Returns the length of the details array


```solidity
function detailsLength() external view returns (uint256 _length);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_length`|`uint256`|The length of the details array|


### getLatestAuction

Returns the latest auction

*Returns an empty struct if there are no auctions*


```solidity
function getLatestAuction() external view returns (Detail memory _latestAuction);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_latestAuction`|`Detail`|The latest auction struct|


### startAuction

Starts a new auction

*Requires an ERC20 allowance on the tokenSell prior to calling*


```solidity
function startAuction(StartAuctionParams calldata _params) external nonReentrant returns (uint256 _auctionNumber);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_params`|`StartAuctionParams`|StartAuctionParams|


### stopAuction

Ends the auction

*Only callable by the auction owner*


```solidity
function stopAuction() public nonReentrant returns (uint256 tokenBuyReceived, uint256 tokenSellRemaining);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tokenBuyReceived`|`uint256`|Amount of tokenBuy obtained from the auction|
|`tokenSellRemaining`|`uint256`|Amount of unsold tokenSell left over|


### swap

Swaps tokenBuys for tokenSells

*This low-level function should be called from a contract which performs important safety checks*

*Token0 is always the TOKEN_BUY, token1 is always the TOKEN_SELL*

*Maintains uniV2 interface*


```solidity
function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes memory data) public nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount0Out`|`uint256`|The amount of tokenBuys to receive|
|`amount1Out`|`uint256`|The amount of tokenSells to receive|
|`to`|`address`|The recipient of the output tokens|
|`data`|`bytes`|Callback data|


### swapExactTokensForTokens

Swaps an exact amount of input tokens for as many output tokens as possible

*Must have an allowance on the TOKEN_BUY prior to invocation*

*Maintains uniV2 interface*


```solidity
function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline) external returns (uint256[] memory _amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|The amount of buy tokens to send.|
|`amountOutMin`|`uint256`|The minimum amount of sell tokens that must be received for the transaction not to revert|
|`path`|`address[]`||
|`to`|`address`|Recipient of the output tokens|
|`deadline`|`uint256`|Unix timestamp after which the transaction will revert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_amounts`|`uint256[]`|The input token amount and output token amount|


### swapTokensForExactTokens

Receives an exact amount of output tokens for as few input tokens as possible

*Must have an allowance on the TOKEN_BUY prior to invocation*

*Maintains uniV2 interface*


```solidity
function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory _amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountOut`|`uint256`|The amount of sell tokens to receive|
|`amountInMax`|`uint256`|The maximum amount of buy tokens that can be required before the transaction reverts|
|`path`|`address[]`||
|`to`|`address`|Recipient of the output tokens|
|`deadline`|`uint256`|Unix timestamp after which the transaction will revert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_amounts`|`uint256[]`|The input token amount and output token amount|


### _withdrawAnyAvailableTokens

Withdraw available TOKEN_BUY and TOKEN_SELL on startAuction() and stopAuction()


```solidity
function _withdrawAnyAvailableTokens(bool _excess) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_excess`|`bool`|Whether to bookkeep any excess tokens received outside of auction|


### _withdrawIfTokenBalance

Withdraw available TOKEN_BUY and TOKEN_SELL on startAuction() and stopAuction()


```solidity
function _withdrawIfTokenBalance(address _token, uint256 _priorBalance, bool _excess) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|Address of the token you want to withdraw|
|`_priorBalance`|`uint256`|Prior balance of the _token|
|`_excess`|`bool`|Whether to bookkeep any excess tokens received outside of auction|


### safeUint128

*Overflow protection*


```solidity
function safeUint128(uint256 number) internal pure returns (uint128 casted);
```

## Events
### AuctionStopped
*Emitted when an auction is stopped*


```solidity
event AuctionStopped(uint256 auctionNumber, uint256 tokenBuyReceived, uint256 tokenSellRemaining);
```

### Buy
*Emitted when a swap occurs and has more information than the ```Swap``` event*


```solidity
event Buy(uint256 auctionNumber, address tokenBuy, address tokenSell, uint128 amountIn, uint128 amountOut, uint128 priceLast, uint128 slippagePerTokenSell);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionNumber`|`uint256`|The ID of the auction, and index in the details array|
|`tokenBuy`|`address`|The token used to buy the tokenSell being auctioned off|
|`tokenSell`|`address`|The token being auctioned off|
|`amountIn`|`uint128`|Amount of tokenBuy in|
|`amountOut`|`uint128`|Amount of tokenSell out|
|`priceLast`|`uint128`|The execution price of the buy|
|`slippagePerTokenSell`|`uint128`|How many tokenBuys (per tokenSell) were added as slippage|

### Swap
Emitted when a swap occurs


```solidity
event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address indexed to);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address of the sender|
|`amount0In`|`uint256`|The amount of TOKEN_BUY in|
|`amount1In`|`uint256`|The amount of TOKEN_SELL in|
|`amount0Out`|`uint256`|The amount of TOKEN_BUY out|
|`amount1Out`|`uint256`|The amount of TOKEN_SELL out|
|`to`|`address`|The address of the recipient|

### AuctionStarted
*Emitted when an auction is started*


```solidity
event AuctionStarted(uint256 auctionNumber, uint128 amountListed, uint128 priceStart, uint128 priceMin, uint128 priceDecay, uint128 priceSlippage, uint32 expiry);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionNumber`|`uint256`|The ID of the auction|
|`amountListed`|`uint128`|Amount of tokenSell being sold|
|`priceStart`|`uint128`|Starting price of the tokenSell, in tokenBuy|
|`priceMin`|`uint128`|Minimum price of the tokenSell, in tokenBuy|
|`priceDecay`|`uint128`|Price decay, per day, using PRECISION|
|`priceSlippage`|`uint128`|Slippage fraction. E.g (0.01 * PRECISION) = 1%|
|`expiry`|`uint32`|Expiration time of the auction|

## Errors
### AuctionNotActive
Emitted when a user attempts to end an auction that has been stopped


```solidity
error AuctionNotActive();
```

### AuctionExpired
Emitted when a user attempts to interact with an auction that has expired


```solidity
error AuctionExpired();
```

### LastAuctionStillActive
Emitted when a user attempts to start a new auction before the previous one has been stopped (via ```stopAuction()```)


```solidity
error LastAuctionStillActive();
```

### InsufficientOutputAmount
Emitted when a user attempts to swap a given amount of buy tokens that would result in an insufficient amount of sell tokens


```solidity
error InsufficientOutputAmount(uint256 minOut, uint256 actualOut);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minOut`|`uint256`|Minimum out that the user expects|
|`actualOut`|`uint256`|Actual amount out that would occur|

### InsufficientInputAmount
Emitted when a user attempts to swap an insufficient amount of buy tokens


```solidity
error InsufficientInputAmount(uint256 minIn, uint256 actualIn);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minIn`|`uint256`|Minimum in that the contract requires|
|`actualIn`|`uint256`|Actual amount in that has been deposited|

### ExcessiveInputAmount
Emitted when a user attempts to swap an excessive amount of buy tokens for aa given amount of sell tokens


```solidity
error ExcessiveInputAmount(uint256 minIn, uint256 actualIn);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minIn`|`uint256`|Minimum in that the user expects|
|`actualIn`|`uint256`|Actual amount in that would occur|

### InsufficientTokenSellsAvailable
Emitted when a user attempts to buy more sell tokens than are left in the auction


```solidity
error InsufficientTokenSellsAvailable();
```

### InputAmountZero
Emitted when attempting to swap where the calculated amountIn is 0


```solidity
error InputAmountZero();
```

### ExcessiveTokenBuyOut
Emitted when a user attempts to buy the tokenBuy using the swap() function


```solidity
error ExcessiveTokenBuyOut(uint256 minOut, uint256 actualOut);
```

### Expired
Emitted when a user attempts to make a swap after the transaction deadline has passed


```solidity
error Expired();
```

### InvalidTokenIn
Emitted when a user attempts to use an invalid buy token


```solidity
error InvalidTokenIn();
```

### InvalidTokenOut
Emitted when a user attempts to use an invalid sell token


```solidity
error InvalidTokenOut();
```

### PriceMinAndSlippageBothZero
Emitted when calling `startAuction()` when `StartAuctionParams.priceMin == 0 && StartAuctionParams.priceSlippage == 0`


```solidity
error PriceMinAndSlippageBothZero();
```

### NotImplemented
Emitted when attempting to call a uni-v2 pair function that is not supported by this contract


```solidity
error NotImplemented();
```

### Overflow
Emitted when downcasting a uint on type overflow


```solidity
error Overflow();
```

### PriceStartLessThanPriceMin
Emitted when a user attempts to start an auction with `_params.priceStart < _params.priceMin`


```solidity
error PriceStartLessThanPriceMin();
```

### AmountListed
Emitted when a user attempts to start an auction selling too-few tokens


```solidity
error AmountListed();
```