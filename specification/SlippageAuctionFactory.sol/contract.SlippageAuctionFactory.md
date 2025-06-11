# SlippageAuctionFactory
[Git Source](https://github.com/fraxfinance/frax-bonds/blob/master/src/contracts/SlippageAuctionFactory.sol)

Permission-less factory to create SlippageAuction.sol contracts.

*https://github.com/FraxFinance/frax-bonds*


## State Variables
### auctions
The auctions addresses created by this factory


```solidity
address[] public auctions;
```


### isAuction
Mapping of auction addresses to whether or not the auction has been created


```solidity
mapping(address auction => bool exists) public isAuction;
```


## Functions
### createAuctionContract

Creates a new auction contract

*Tokens must be 18 decimals*


```solidity
function createAuctionContract(address _timelock, address _tokenBuy, address _tokenSell) external returns (address auction);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelock`|`address`|Timelock role for auction|
|`_tokenBuy`|`address`|Token used to purchase `_tokenSell`|
|`_tokenSell`|`address`|Token sold in the auction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`address`|The address of the new SlippageAuction that was created|


### getAuctions

Returns a list of all auction addresses deployed


```solidity
function getAuctions() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|memory address[] The list of auction addresses|


### getAuction

Get an auction address by index to save on-chain gas usage from returning the whole auctions array

*Reverts if attempting to return an index greater than the auctions array length*


```solidity
function getAuction(uint256 _index) external view returns (address auction);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|Index of auction address to request from the auctions array|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`address`|Address of the specified auction|


### auctionsLength

Returns the number of auctions deployed


```solidity
function auctionsLength() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 length of the auctions array|


## Events
### AuctionCreated
Emitted when a new auction is created


```solidity
event AuctionCreated(address indexed auction, address indexed tokenBuy, address indexed tokenSell);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`address`|     The address of the new auction contract|
|`tokenBuy`|`address`|    Token to purchase `tokenSell`|
|`tokenSell`|`address`|   Token sold in the auction|

## Errors
### AuctionAlreadyExists
Thrown when an auction with the same sender and tokens has already been created


```solidity
error AuctionAlreadyExists();
```

### AuctionDoesNotExist
Thrown when attempting to call `getAuction()` with an index greater than auctions.length


```solidity
error AuctionDoesNotExist();
```

### TokenSellMustBe18Decimals
Thrown when the sell token is not 18 decimals


```solidity
error TokenSellMustBe18Decimals();
```

### TokenBuyMustBe18Decimals
Thrown when the buy token is not 18 decimals


```solidity
error TokenBuyMustBe18Decimals();
```

