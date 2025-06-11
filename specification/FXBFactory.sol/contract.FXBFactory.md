# FXBFactory
[Git Source](https://github.com/fraxfinance/frax-bonds/blob/master/src/contracts/FXBFactory.sol)

**Inherits:**
Timelock2Step

Deploys FXB ERC20 contracts

*"FXB" and "bond" are interchangeable*

*https://github.com/FraxFinance/frax-bonds*


## State Variables
### FRAX
The Frax token contract


```solidity
address public immutable FRAX;
```


### fxbs
Array of bond addresses


```solidity
address[] public fxbs;
```


### isFxb
Whether a given address is a bond


```solidity
mapping(address _fxb => bool _isFxb) public isFxb;
```


### isTimestampFxb
Whether a given timestamp has a bond deployed


```solidity
mapping(uint256 _timestamp => bool _isFxb) public isTimestampFxb;
```


## Functions
### constructor

Constructor


```solidity
constructor(address _timelock, address _frax) Timelock2Step(_timelock);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timelock`|`address`|The owner of this contract|
|`_frax`|`address`|The address of the FRAX token|


### _monthNames

This function returns the 3 letter name of a month, given its index


```solidity
function _monthNames(uint256 _monthIndex) internal pure returns (string memory _monthName);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_monthIndex`|`uint256`|The index of the month|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_monthName`|`string`|The name of the month|


### fxbsLength

Returns the total number of bonds addresses created


```solidity
function fxbsLength() public view returns (uint256 _length);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_length`|`uint256`|uint256 Number of bonds addresses created|


### _generateSymbol

Generates the bond symbol in the format FXB_YYYYMMDD


```solidity
function _generateSymbol(uint256 _maturityTimestamp) internal pure returns (string memory symbol);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maturityTimestamp`|`uint256`|Date the bond will mature|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|The symbol of the bond|


### _generateName

Generates the bond name in the format FXB_ID_MMMDDYYYY


```solidity
function _generateName(uint256 _id, uint256 _maturityTimestamp) internal pure returns (string memory name);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_id`|`uint256`|The id of the bond|
|`_maturityTimestamp`|`uint256`|Date the bond will mature|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|The name of the bond|


### createFxbContract

Generates a new bond contract


```solidity
function createFxbContract(uint256 _maturityTimestamp) external returns (address fxb, uint256 id);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maturityTimestamp`|`uint256`|Date the bond will mature and be redeemable|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fxb`|`address`|The address of the new bond|
|`id`|`uint256`|The id of the new bond|


## Events
### BondCreated
Emitted when a new bond is created


```solidity
event BondCreated(address fxb, uint256 id, string symbol, string name, uint256 maturityTimestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fxb`|`address`|Address of the bond|
|`id`|`uint256`|The ID of the bond|
|`symbol`|`string`|The bond's symbol|
|`name`|`string`|Name of the bond|
|`maturityTimestamp`|`uint256`|Date the bond will mature|

## Errors
### InvalidMonthNumber
Thrown when an invalid month number is passed


```solidity
error InvalidMonthNumber();
```

### BondMaturityAlreadyExists
Thrown when a bond with the same maturity already exists


```solidity
error BondMaturityAlreadyExists();
```

### BondMaturityAlreadyExpired
Thrown when attempting to create a bond with an expiration before the current time


```solidity
error BondMaturityAlreadyExpired();
```

