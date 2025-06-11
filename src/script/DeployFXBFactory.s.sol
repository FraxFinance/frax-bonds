// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import { FXBFactory } from "src/contracts/FXBFactory.sol";
import { SlippageAuction } from "src/contracts/SlippageAuction.sol";
import { SlippageAuctionFactory } from "src/contracts/SlippageAuctionFactory.sol";
import "src/Constants.sol" as Constants;

function deployFXBFactory() returns (FXBFactory iFactory, address factory) {
    iFactory = new FXBFactory(0xb0E1650A9760e0f383174af042091fc544b8356f, 0xFc00000000000000000000000000000000000001);
    factory = address(iFactory);
}

function deployFXBFactoryManual(address _owner, address _underlyingTkn) returns (FXBFactory iFactory, address factory) {
    iFactory = new FXBFactory(_owner, _underlyingTkn);
    factory = address(iFactory);
}

contract DeployFXBFactory is BaseScript {
    function run() public broadcaster {
        deployFXBFactory();
    }
}
