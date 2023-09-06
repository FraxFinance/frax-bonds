// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import { DeployAll } from "../script/DeployAll.sol";
import { FXB } from "../contracts/FXB.sol";
import { FXBFactory } from "../contracts/FXBFactory.sol";
import { SlippageAuction } from "../contracts/SlippageAuction.sol";
import { SlippageAuctionFactory } from "../contracts/SlippageAuctionFactory.sol";
import { SigUtils } from "./utils/SigUtils.sol";
import "../Constants.sol" as Constants;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseTest is FraxTest, Constants.Helper {
    // Used in tests
    DeployAll public deployContract;

    // An unprivileged test user
    uint256 internal testerPrivateKey;
    address payable internal tester;

    // An unprivileged bond user
    uint256 internal bonduserPrivateKey;
    address payable internal bonduser;

    IERC20 public frax = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    // Test tokens
    IERC20 public fxs = IERC20(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    IERC20 public usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // FXBFactory
    FXBFactory public factory;
    address public factoryAddress;

    // SlippageAuctionFactory
    SlippageAuctionFactory public auctionFactory;
    address public auctionFactoryAddress;

    function defaultSetup() internal {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_105_462);

        // Deploy the contracts
        // ======================

        // Deploy all of the contracts
        deployContract = DeployAll(new DeployAll());
        deployContract.run();

        // FXBFactory
        factory = FXBFactory(deployContract.factory());
        factoryAddress = address(factory);

        // Auction Factory
        auctionFactory = SlippageAuctionFactory(deployContract.auctionFactory());
        auctionFactoryAddress = address(auctionFactory);

        // Set up the unprivileged test user
        testerPrivateKey = 0xA11CE;
        tester = payable(vm.addr(testerPrivateKey));

        // Give the tester 1000 FRAX
        hoax(Constants.Mainnet.FRAX_WHALE);
        frax.transfer(tester, 1000e18);

        // Label the tester
        vm.label(tester, "tester");

        // Set up the unprivileged bond user
        bonduserPrivateKey = 0xB0B;
        bonduser = payable(vm.addr(bonduserPrivateKey));

        // Give the bonduser 1000000 FRAX
        hoax(Constants.Mainnet.FRAX_WHALE);
        frax.transfer(bonduser, 1_000_000e18);

        // Label the bonduser
        vm.label(bonduser, "bonduser");
    }
}
