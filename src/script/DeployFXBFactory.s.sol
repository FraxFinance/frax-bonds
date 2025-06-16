// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import { FXBFactory } from "src/contracts/FXBFactory.sol";
import { FraxUpgradeableProxy } from "src/contracts/FraxUpgradeableProxy.sol";

import "src/Constants.sol" as Constants;

function deployFXBFactory() returns (FXBFactory iFactory, address factory) {
    address implementation = address(new FXBFactory());

    bytes memory data = abi.encodeCall(
        FXBFactory.initialize,
        (
            0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6,
            0xff000000000000000000000000000000000001Fd // LFRAX
        )
    );
    FraxUpgradeableProxy proxy = new FraxUpgradeableProxy({
        _logic: implementation,
        _initialAdmin: 0xfC0000000000000000000000000000000000000a,
        _data: data
    });
    iFactory = FXBFactory(address(proxy));
    factory = address(iFactory);
}

function deployFXBFactoryManual(
    address _owner,
    address _proxyAdmin,
    address _token
) returns (FXBFactory iFactory, address factory) {
    address implementation = address(new FXBFactory());

    bytes memory data = abi.encodeCall(FXBFactory.initialize, (_owner, _token));
    FraxUpgradeableProxy proxy = new FraxUpgradeableProxy({
        _logic: implementation,
        _initialAdmin: _proxyAdmin,
        _data: data
    });

    iFactory = FXBFactory(address(proxy));
    factory = address(iFactory);
}

contract DeployFXBFactory is BaseScript {
    function run() public broadcaster {
        deployFXBFactory();
    }
}
