## Storage Layout (Deployed contracts)
```source .env && cast storage --chain-id 252 --rpc-url $FRAXTAL_MAINNET_URL --etherscan-api-key $FRAXTAL_API_KEY 0xacA9A33698cF96413A40A4eB9E87906ff40fC6CA``` <!-- frxUSD (ex FRAX) -->
```source .env && cast storage --chain-id 252 --rpc-url $FRAXTAL_MAINNET_URL --etherscan-api-key $FRAXTAL_API_KEY 0xfc00000000000000000000000000000000000002```
```source .env && cast storage --chain-id 252 --rpc-url $FRAXTAL_MAINNET_URL --etherscan-api-key $FRAXTAL_API_KEY 0x17FdBAdAc06C76C73Ea73b834341b02779C36AA0```

## Storage Layout (Undeployed contracts)
```forge inspect src/contracts/FXB.sol:FXB storageLayout```
```forge inspect src/contracts/FXB_LFRAX.sol:FXB_LFRAX storageLayout```

## Testing
<!-- LFRAX upgrade only -->
```clear && source .env && forge test --mc FXB_LFRAX_Test -vvvv```
```clear && source .env && forge test --mc LFRAX_Upgrade_Test -vvvv``` 

## Code Coverage
```clear && source .env && forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage```
OR, if you get "stack too deep" issues
```clear && source .env &&  forge coverage --ir-minimum --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage```

## Deploy Examples
<!-- Fraxtal -->
```source .env && forge script src/script/VestedFXS-and-Flox/DeployFPISLocker.s.sol:DeployFPISLocker --chain-id 252 --with-gas-price 15000 --priority-gas-price 1000 --rpc-url $FRAXTAL_MAINNET_URL --verifier-url $FRAXSCAN_API_URL --etherscan-api-key $FRAXTAL_API_KEY --optimize --optimizer-runs 200 --use "0.8.26" --evm-version "cancun" --private-key $PK --broadcast```


<!-- LFRAX FXB Upgrade L2 (IRL Prod) -->
<!-- ================================================================== -->
<!-- 00 -->
```source .env && forge script src/script/LFRAX_FXB_Upgrade/00_DeployImpls.s.sol:DeployImpls --chain-id 252 --with-gas-price 150000 --priority-gas-price 10000 --rpc-url $FRAXTAL_MAINNET_URL --optimize --optimizer-runs 999999 --use "0.8.26" --evm-version "cancun" --broadcast --slow --verify --verifier=etherscan --retries=3 --verifier-url=$FRAXSCAN_API_URL --verifier-api-key $FRAXTAL_API_KEY```
<!-- 01 -->
```source .env && forge script src/script/LFRAX_FXB_Upgrade/01_HandleNewLFRAX.s.sol:HandleNewLFRAX --chain-id 252 --with-gas-price 150000 --priority-gas-price 10000 --rpc-url $FRAXTAL_MAINNET_URL --optimize --optimizer-runs 999999 --use "0.8.26" --evm-version "cancun" --broadcast --slow --verify --verifier=etherscan --retries=3 --verifier-url=$FRAXSCAN_API_URL --verifier-api-key $FRAXTAL_API_KEY```
<!-- 02 -->
```source .env && forge script src/script/LFRAX_FXB_Upgrade/02_UpgradeFXBs.s.sol:UpgradeFXBs --chain-id 252 --with-gas-price 150000 --priority-gas-price 10000 --rpc-url $FRAXTAL_MAINNET_URL --optimize --optimizer-runs 999999 --use "0.8.26" --evm-version "cancun" --broadcast --slow --verify --verifier=etherscan --retries=3 --verifier-url=$FRAXSCAN_API_URL --verifier-api-key $FRAXTAL_API_KEY```