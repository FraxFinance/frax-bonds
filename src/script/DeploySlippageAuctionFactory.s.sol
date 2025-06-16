// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import { FXBFactory } from "src/contracts/FXBFactory.sol";
import { SlippageAuction } from "src/contracts/SlippageAuction.sol";
import { SlippageAuctionFactory } from "src/contracts/SlippageAuctionFactory.sol";
import "src/Constants.sol" as Constants;

function deploySlippageAuctionFactory() returns (SlippageAuctionFactory iFactory, address factory) {
    iFactory = new SlippageAuctionFactory();
    factory = address(iFactory);
}

contract DeploySlippageAuctionFactory is BaseScript {
    function run() public broadcaster {
        deploySlippageAuctionFactory();
    }
}
