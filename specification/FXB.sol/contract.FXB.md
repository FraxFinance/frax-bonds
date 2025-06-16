# FXB
[Git Source](https://github.com/fraxfinance/frax-bonds/blob/master/src/contracts/FXB.sol)

**Inherits:**
ERC20, ERC20Permit

The FXB token can be redeemed for 1 FRAX at a later date. Created via factory.

*https://github.com/FraxFinance/frax-bonds*


## State Variables
### FRAX
The Frax token contract


```solidity
IERC20 public immutable FRAX;
```


### MATURITY_TIMESTAMP
Timestamp of bond maturity


```solidity
uint256 public immutable MATURITY_TIMESTAMP;
```


### totalFxbMinted
Total amount of FXB minted


```solidity
uint256 public totalFxbMinted;
```


### totalFxbRedeemed
Total amount of FXB redeemed


```solidity
uint256 public totalFxbRedeemed;
```

## Structs
### BondInfo
Bond Information


```solidity
struct BondInfo {
    string symbol;
    string name;
    uint256 maturityTimestamp;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|The symbol of the bond|
|`name`|`string`|The name of the bond|
|`maturityTimestamp`|`uint256`|Timestamp the bond will mature|


## Functions
### constructor

Called by the factory


```solidity
constructor(string memory name_, string memory symbol_,address _frax, uint256 _maturityTimestamp) ERC20(name_, symbol_) ERC20Permit(name_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|The name of the bond|
|`symbol_`|`string`|The symbol of the bond|
|`_frax`|`address`|The address of the FRAX token|
|`_maturityTimestamp`|`uint256`|Timestamp the bond will mature and be redeemable|


### bondInfo

Returns summary information about the bond


```solidity
function bondInfo() external view returns (BondInfo memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`BondInfo`|BondInfo Summary of the bond|


### isRedeemable

Returns a boolean representing whether a bond can be redeemed


```solidity
function isRedeemable() public view returns (bool _isRedeemable);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_isRedeemable`|`bool`|If the bond is redeemable|

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

### mint

Mints a specified amount of tokens to the account, requires caller to approve on the FRAX contract in an amount equal to the minted amount

*Supports OZ 5.0 interfacing with named variable arguments*


```solidity
function mint(address account, uint256 value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to receive minted tokens|
|`value`|`uint256`|The amount of the token to mint|


### burn

Redeems FXB 1-to-1 for FRAX

*Supports OZ 5.0 interfacing with named variable arguments*


```solidity
function burn(address to, uint256 value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient of redeemed FRAX|
|`value`|`uint256`|Amount to redeem|


## Errors
### BondNotRedeemable
Thrown if the bond hasn't matured yet, or redeeming is paused


```solidity
error BondNotRedeemable();
```

### ZeroAmount
Thrown if attempting to mint / burn zero tokens


```solidity
error ZeroAmount();
```