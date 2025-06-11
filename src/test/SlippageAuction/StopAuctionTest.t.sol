// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import "../BaseTest.t.sol";
import { SigUtils } from "../utils/SigUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FxbFactoryHelper } from "../helpers/FxbFactoryHelper.sol";
import { AuctionFactoryHelper } from "../helpers/AuctionFactoryHelper.sol";
import { AuctionHelper } from "../helpers/AuctionHelper.sol";

contract StopAuctionTest is BaseTest, FxbFactoryHelper, AuctionFactoryHelper, AuctionHelper {
    using SafeCast for *;

    // Across test
    address timelock;

    // Across withdrawal tests
    uint256 amountExcessBuy = amountListed / 4;
    uint256 amountExcessSell = amountListed * 3;
    uint256 amountBuySpent;
    uint256 amountSellReceived;

    function setUp() public {
        defaultSetup();

        /// BACKGROUND: deploy one bond
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + 75 days);
        /// BACKGROUND: an auction has been deployed by TIMELOCK
        (iAuction, auction) = _auctionFactory_createAuctionContract({ _tokenBuy: frax, _tokenSell: fxb });

        /// BACKGROUND: starts the auction with properly formed params
        _auction_startAuction(
            iAuction,
            SlippageAuction.StartAuctionParams({
                amountListed: amountListed,
                priceStart: priceStart,
                priceMin: priceMin,
                priceDecay: priceDecay,
                priceSlippage: priceSlippage,
                expiry: expiry
            })
        );

        /// BACKGROUND: setting the timelock
        timelock = iAuction.timelockAddress();
    }

    function test_StopAuction_succeeds() public {
        //==============================================================================
        // Act
        //==============================================================================

        SlippageAuctionStorageSnapshot memory initial_auctionSnapshot = slippageAuctionStorageSnapshot(iAuction);
        AccountStorageSnapshot memory initial_timelockSnapshot = accountStorageSnapshot(timelock, iFrax, iFxb);

        hoax(timelock);
        (uint256 tokenBuyReceived, uint256 tokenSellRemaining) = iAuction.stopAuction();

        DeltaSlippageAuctionStorageSnapshot memory delta_auctionSnapshot = deltaSlippageAuctionStorageSnapshot(
            initial_auctionSnapshot
        );
        DeltaAccountStorageSnapshot memory delta_timelockSnapshot = deltaAccountStorageSnapshot(
            initial_timelockSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "/// THEN: auction should have changed active state",
            a: delta_auctionSnapshot.delta.latestAuction.active,
            b: true
        });
        assertEq({
            err: "/// THEN: auction should not be active",
            a: delta_auctionSnapshot.end.latestAuction.active,
            b: false
        });

        assertEq({
            err: "/// THEN: detail.tokenBuyReceived incorrect",
            a: delta_auctionSnapshot.end.latestAuction.tokenBuyReceived,
            b: tokenBuyReceived
        });

        assertEq({
            err: "/// THEN: detail.amountLeft incorrect",
            a: delta_auctionSnapshot.end.latestAuction.amountLeft,
            b: tokenSellRemaining
        });

        assertEq({
            err: "/// THEN: tokenBuy received amount incorrect",
            a: delta_timelockSnapshot.delta.fraxSnapshot.balanceOf,
            b: tokenBuyReceived
        });

        assertEq({
            err: "/// THEN: tokenSell received amount incorrect",
            a: delta_timelockSnapshot.delta.fxbSnapshot.balanceOf,
            b: tokenSellRemaining
        });
    }

    function test_StopAuction_WithdrawIfExcessTokenNoneSold_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================
        /// BACKGROUND: there have been no swaps since the auction has started
        amountSellReceived = 0;
        amountBuySpent = 0;

        _stopAuction_WithdrawTest();
    }

    function test_StopAuction_WithdrawIfExcessTokenSomeSold_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: there have been some swaps since the auction has started
        amountBuySpent = amountListed / 5;
        _mintFraxTo(timelock, amountBuySpent);

        vm.startPrank(timelock);
        iFrax.approve(auction, amountBuySpent);
        uint256[] memory amounts = iAuction.swapExactTokensForTokens({
            amountIn: amountBuySpent,
            amountOutMin: 0,
            path: new address[](0),
            to: timelock,
            deadline: block.timestamp + 1 days
        });
        vm.stopPrank();

        amountSellReceived = amounts[amounts.length - 1];

        assertTrue(amountSellReceived < amountListed && amountSellReceived > 0);

        _stopAuction_WithdrawTest();
    }

    function test_StopAuction_WithdrawIfExcessTokenAllSold_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: All tokens listed for auction have been sold
        amountBuySpent = iAuction.getAmountIn(amountListed, fxb);
        _mintFraxTo(timelock, amountBuySpent);

        vm.startPrank(timelock);
        iFrax.approve(auction, amountBuySpent);
        uint256[] memory amounts = iAuction.swapExactTokensForTokens({
            amountIn: amountBuySpent,
            amountOutMin: 0,
            path: new address[](0),
            to: timelock,
            deadline: block.timestamp + 1 days
        });
        vm.stopPrank();

        amountSellReceived = amounts[amounts.length - 1];

        assertEq({ err: "/// THEN: incorrect amountSellReceived", a: amountSellReceived, b: amountListed });

        _stopAuction_WithdrawTest();
    }

    function _stopAuction_WithdrawTest() internal {
        /// GIVEN: the auction has received donated buy/sellToken before auction close

        // Give excess buyToken to the auction
        _mintFraxTo(auction, amountExcessBuy);

        // Gives excess sellToken to the auction
        _mintFraxTo(timelock, amountExcessSell);
        vm.startPrank(timelock);
        iFrax.approve(fxb, amountExcessSell);
        iFxb.mint(auction, amountExcessSell);
        vm.stopPrank();

        //==============================================================================
        // Act
        //==============================================================================

        SlippageAuctionStorageSnapshot memory initial_auctionSnapshot = slippageAuctionStorageSnapshot(iAuction);

        /// WHEN: stopping an auction
        hoax(timelock);
        iAuction.stopAuction();

        DeltaSlippageAuctionStorageSnapshot memory delta_auctionSnapshot = deltaSlippageAuctionStorageSnapshot(
            initial_auctionSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "/// THEN: incorrect delta detail.amountLeft",
            a: delta_auctionSnapshot.delta.latestAuction.amountLeft,
            b: 0
        });

        assertEq({
            err: "/// THEN: incorrect end detail.amountLeft",
            a: delta_auctionSnapshot.end.latestAuction.amountLeft,
            b: amountListed - amountSellReceived
        });

        assertEq({
            err: "/// THEN: incorrect detail.amountExcessBuy",
            a: delta_auctionSnapshot.delta.latestAuction.amountExcessBuy,
            b: amountExcessBuy
        });

        assertEq({
            err: "/// THEN: incorrect detail.amountExcessSell",
            a: delta_auctionSnapshot.delta.latestAuction.amountExcessSell,
            b: amountExcessSell
        });

        assertEq({
            err: "/// THEN: incorrect delta detail.tokenBuyReceived",
            a: delta_auctionSnapshot.end.latestAuction.tokenBuyReceived,
            b: amountBuySpent
        });

        assertEq({
            err: "/// THEN: incorrect end detail.tokenBuyReceived",
            a: delta_auctionSnapshot.end.latestAuction.tokenBuyReceived,
            b: amountBuySpent
        });
    }

    function test_StopAuction_NotTimelock_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: tester attempts to stop auction
        hoax(tester);
        vm.expectRevert();
        iAuction.stopAuction();

        /// THEN: reverts
    }

    function test_StopAuction_AuctionNotActive_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: the most recent auction was ended
        startHoax(timelock);
        iAuction.stopAuction();

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: timelock attempts to stop auction
        vm.expectRevert(SlippageAuction.AuctionNotActive.selector);
        iAuction.stopAuction();

        /// THEN: reverts
    }
}
