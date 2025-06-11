// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "./BaseTest.t.sol";
import { FxbFactoryHelper } from "./helpers/FxbFactoryHelper.sol";
import { AuctionFactoryHelper } from "./helpers/AuctionFactoryHelper.sol";

contract SlippageAuctionFactoryTest is BaseTest, AuctionFactoryHelper, FxbFactoryHelper {
    function test_Auction_Version() public {
        /// BACKGROUND: Contracts are deployed
        defaultSetup();

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: a user tries to create an auction
        (iAuction, auction) = _auctionFactory_createAuctionContract(frax, fxs);

        //==============================================================================
        // Assert
        //==============================================================================

        (uint256 major, uint256 minor, uint256 patch) = iAuction.version();
        assertEq({ err: "/// THEN: major incorrect", a: major, b: 1 });
        assertEq({ err: "/// THEN: minor incorrect", a: minor, b: 0 });
        assertEq({ err: "/// THEN: patch incorrect", a: patch, b: 1 });
    }

    function test_CreateAuctionContract_succeeds() public {
        /// BACKGROUND: Contracts are deployed
        defaultSetup();

        uint256 auctionsLengthStart = iAuctionFactory.auctionsLength();

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: a user tries to create an auction with 2 x 18 decimal tokens
        (iAuction, auction) = _auctionFactory_createAuctionContract(frax, fxs);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "/// THEN: Auctions length should increase by 1",
            a: iAuctionFactory.auctionsLength() - auctionsLengthStart,
            b: 1
        });

        assertEq({
            err: "/// THEN: Auction address should be the last address in the auctions array",
            a: iAuctionFactory.auctions(iAuctionFactory.auctionsLength() - 1),
            b: auction
        });

        assertEq({ err: "/// THEN: Buy token should be FRAX", a: iAuction.TOKEN_BUY(), b: frax });

        assertEq({ err: "/// THEN: Sell token should be FXS", a: iAuction.TOKEN_SELL(), b: fxs });

        assertEq({
            err: "/// THEN: Timelock address incorrect",
            a: iAuction.timelockAddress(),
            b: Constants.Mainnet.FXB_TIMELOCK
        });

        assertEq({ err: "/// THEN: auction not added to isAuction", a: iAuctionFactory.isAuction(auction), b: true });
    }

    function test_CreateAuctionContract_MultipleCreations_succeeds() public {
        /// BACKGROUND: Contracts are deployed
        defaultSetup();

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: a user creates two of the same auction
        _auctionFactory_createAuctionContract(frax, address(iFxs));

        _auctionFactory_createAuctionContract(frax, address(iFxs));

        /// THEN: succeeds
    }

    function test_CreateAuctionContract_NewOwner_succeeds() public {
        /// BACKGROUND: contracts deployed
        defaultSetup();

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: a user creates an auction for another owner
        hoax(Constants.Mainnet.FXB_TIMELOCK);
        auction = iAuctionFactory.createAuctionContract({
            _timelock: tester,
            _tokenBuy: frax,
            _tokenSell: address(iFxs)
        });

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "/// THEN: tester should be auction owner",
            a: SlippageAuction(auction).timelockAddress(),
            b: tester
        });
    }

    function test_CreateAuctionContract_TokenNot18Decimals_reverts() public {
        /// BACKGROUND: Deploy the contracts
        defaultSetup();

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: a user tries to create an auction with a non 18 decimal BUY token
        vm.expectRevert(SlippageAuctionFactory.TokenBuyMustBe18Decimals.selector);
        iAuctionFactory.createAuctionContract(address(0), usdc, frax);
        /// THEN: we expect the function to revert

        /// WHEN: a user tries to create an auction with a non 18 decimal SELL token
        vm.expectRevert(SlippageAuctionFactory.TokenSellMustBe18Decimals.selector);
        iAuctionFactory.createAuctionContract(address(0), frax, usdc);
        /// THEN: we expect the function to revert
    }

    function test_GetAuctions() public {
        /// BACKGROUND: Deploy the contracts
        defaultSetup();

        //==============================================================================
        // Act
        //==============================================================================

        /// GIVEN: 3 auctions have been created
        (, address fxb0) = _fxbFactory_createFxbContract(block.timestamp + 30 days);
        (, address auction1) = _auctionFactory_createAuctionContract(frax, fxb0);
        (, address fxb1) = _fxbFactory_createFxbContract(block.timestamp + 60 days);
        (, address auction2) = _auctionFactory_createAuctionContract(frax, fxb1);
        (, address fxb2) = _fxbFactory_createFxbContract(block.timestamp + 90 days);
        (, address auction3) = _auctionFactory_createAuctionContract(fxs, fxb2);

        //==============================================================================
        // Assert
        //==============================================================================

        /// WHEN: a user calls getAuctions()
        address[] memory auctions = iAuctionFactory.getAuctions();

        /// THEN: we expect the array to contain the addresses of the 3 auctions
        assertEq(auctions[0], auction1, "First auction should be the first auction");
        assertEq(auctions[1], auction2, "Second auction should be the second auction");
        assertEq(auctions[2], auction3, "Third auction should be the third auction");
    }

    function test_AuctionsLength() public {
        /// BACKGROUND: Deploy the contracts
        defaultSetup();

        //==============================================================================
        // Act
        //==============================================================================

        /// GIVEN: 3 auctions have been created
        (, address fxb0) = _fxbFactory_createFxbContract(block.timestamp + 30 days);
        _auctionFactory_createAuctionContract(frax, fxb0);
        (, address fxb1) = _fxbFactory_createFxbContract(block.timestamp + 60 days);
        _auctionFactory_createAuctionContract(frax, fxb1);
        (, address fxb2) = _fxbFactory_createFxbContract(block.timestamp + 90 days);
        _auctionFactory_createAuctionContract(fxs, fxb2);

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: we expect the function to return 3
        assertEq(iAuctionFactory.auctionsLength(), 3, "Auctions length should be 3");
    }
}
