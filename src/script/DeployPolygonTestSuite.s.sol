// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BaseScript } from "frax-std/BaseScript.sol";
import "frax-std/FraxTest.sol";
import { FXB } from "src/contracts/FXB.sol";
import { FXBFactory } from "src/contracts/FXBFactory.sol";
import { SlippageAuction } from "src/contracts/SlippageAuction.sol";
import { SlippageAuctionFactory } from "src/contracts/SlippageAuctionFactory.sol";
import { deployFXBFactoryManual } from "./DeployFXBFactory.s.sol";
import { deploySlippageAuctionFactory } from "./DeploySlippageAuctionFactory.s.sol";
import "src/Constants.sol" as Constants;

contract DeployPolygonTestSuite is BaseScript {
    // FXB Factory
    FXBFactory public iFxbFactory;
    address public fxbFactory;

    // Slippage Auction
    SlippageAuctionFactory public iAuctionFactory;
    address public auctionFactory;
    address[5] public auctions;

    // Frax
    address public polygonFrax = 0x45c32fA6DF82ead1e2EF74d17b76547EDdFaFF89;
    ERC20 public iPolygonFrax = ERC20(polygonFrax);

    // Bonds
    address[5] public fxbs;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PK");
        deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // // Deploy the factories
        (iFxbFactory, fxbFactory) = deployFXBFactoryManual(
            Constants.Mainnet.POLYGON_DEPLOYER_ADDRESS,
            address(iPolygonFrax)
        );
        (iAuctionFactory, auctionFactory) = deploySlippageAuctionFactory();

        // Create some bonds
        (fxbs[0], ) = iFxbFactory.createFxbContract(block.timestamp + 7 days); // 1 week
        (fxbs[1], ) = iFxbFactory.createFxbContract(block.timestamp + 30 days); // 1 month
        (fxbs[2], ) = iFxbFactory.createFxbContract(block.timestamp + 180 days); // 6 months
        (fxbs[3], ) = iFxbFactory.createFxbContract(block.timestamp + 365 days); // 1 year
        (fxbs[4], ) = iFxbFactory.createFxbContract(block.timestamp + 730 days); // 2 years

        // Mint 15 FRAX each worth of bonds
        iPolygonFrax.approve(fxbs[0], 15e18);
        iPolygonFrax.approve(fxbs[1], 15e18);
        iPolygonFrax.approve(fxbs[2], 15e18);
        iPolygonFrax.approve(fxbs[3], 15e18);
        iPolygonFrax.approve(fxbs[4], 15e18);
        FXB(fxbs[0]).mint(Constants.Mainnet.POLYGON_DEPLOYER_ADDRESS, 15e18);
        FXB(fxbs[1]).mint(Constants.Mainnet.POLYGON_DEPLOYER_ADDRESS, 15e18);
        FXB(fxbs[2]).mint(Constants.Mainnet.POLYGON_DEPLOYER_ADDRESS, 15e18);
        FXB(fxbs[3]).mint(Constants.Mainnet.POLYGON_DEPLOYER_ADDRESS, 15e18);
        FXB(fxbs[4]).mint(Constants.Mainnet.POLYGON_DEPLOYER_ADDRESS, 15e18);

        // Create the auction (will not start yet)
        auctions[0] = iAuctionFactory.createAuctionContract(deployer, polygonFrax, fxbs[0]);
        auctions[1] = iAuctionFactory.createAuctionContract(deployer, polygonFrax, fxbs[1]);
        auctions[2] = iAuctionFactory.createAuctionContract(deployer, polygonFrax, fxbs[2]);
        auctions[3] = iAuctionFactory.createAuctionContract(deployer, polygonFrax, fxbs[3]);
        auctions[4] = iAuctionFactory.createAuctionContract(deployer, polygonFrax, fxbs[4]);

        // Prepare the auction parameters, selling 10 FXB out of the 15 FXB minted
        SlippageAuction.StartAuctionParams memory _auctionParams = SlippageAuction.StartAuctionParams({
            amountListed: 10e18,
            priceStart: 0.95e18,
            priceMin: 0.9e18,
            priceDecay: 0.01e18,
            priceSlippage: 0.01e18 / 100_000,
            expiry: uint32(block.timestamp + 30 days)
        });

        // Start the auctions
        FXB(fxbs[0]).approve(address(auctions[0]), 10e18);
        FXB(fxbs[1]).approve(address(auctions[1]), 10e18);
        FXB(fxbs[2]).approve(address(auctions[2]), 10e18);
        FXB(fxbs[3]).approve(address(auctions[3]), 10e18);
        FXB(fxbs[4]).approve(address(auctions[4]), 10e18);
        SlippageAuction(auctions[0]).startAuction(_auctionParams);
        SlippageAuction(auctions[1]).startAuction(_auctionParams);
        SlippageAuction(auctions[2]).startAuction(_auctionParams);
        SlippageAuction(auctions[3]).startAuction(_auctionParams);
        SlippageAuction(auctions[4]).startAuction(_auctionParams);

        // Print the addresses
        console.log("FXBFactory: ", fxbFactory);
        console.log("SlippageAuctionFactory: ", auctionFactory);

        // Print the FXBs
        for (uint256 i = 0; i < 5; i++) {
            console.log("FXB[%s]: %s", i, fxbs[i]);
        }

        // Print the SlippageAuction
        for (uint256 i = 0; i < 5; i++) {
            console.log("SlippageAuction[%s]: %s", i, auctions[i]);
        }

        vm.stopBroadcast();
    }
}
