// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import "../BaseTest.t.sol";
import { SigUtils } from "../utils/SigUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FxbFactoryHelper } from "../helpers/FxbFactoryHelper.sol";
import { AuctionFactoryHelper } from "../helpers/AuctionFactoryHelper.sol";
import { AuctionHelper } from "../helpers/AuctionHelper.sol";

contract StartAuctionTest is BaseTest, FxbFactoryHelper, AuctionFactoryHelper, AuctionHelper {
    using SafeCast for *;

    function setUp() public {
        defaultSetup();

        /// BACKGROUND: deploy one bond
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + 75 days);

        /// BACKGROUND: an auction has been deployed by TIMELOCK
        (iAuction, auction) = _auctionFactory_createAuctionContract({ _tokenBuy: frax, _tokenSell: fxb });
    }

    function test_StartAuction_succeeds() public {
        //==============================================================================
        // Act
        //==============================================================================
        SlippageAuctionStorageSnapshot memory initial_auctionSnapshot = slippageAuctionStorageSnapshot(iAuction);

        /// WHEN: timelock starts the auction with properly formed params
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

        DeltaSlippageAuctionStorageSnapshot memory delta_auctionSnapshot = deltaSlippageAuctionStorageSnapshot(
            initial_auctionSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "/// THEN: auction should have changed active state",
            a: delta_auctionSnapshot.delta.latestAuction.active,
            b: true
        });

        assertEq({ err: "/// THEN: incorrect detailsLength", a: delta_auctionSnapshot.delta.detailsLength, b: 1 });

        assertEq({
            err: "/// THEN: auction should be active",
            a: delta_auctionSnapshot.end.latestAuction.active,
            b: true
        });

        assertEq({
            err: "/// THEN: incorrect details.amountListed",
            a: delta_auctionSnapshot.delta.latestAuction.amountListed,
            b: amountListed
        });

        assertEq({
            err: "/// THEN: incorrect details.amountLeft",
            a: delta_auctionSnapshot.delta.latestAuction.amountLeft,
            b: amountListed
        });

        assertEq({
            err: "/// THEN: incorrect details.priceLast",
            a: delta_auctionSnapshot.delta.latestAuction.priceLast,
            b: priceStart
        });

        assertEq({
            err: "/// THEN: incorrect details.priceMin",
            a: delta_auctionSnapshot.delta.latestAuction.priceMin,
            b: priceMin
        });

        assertEq({
            err: "/// THEN: incorrect details.priceDecay",
            a: delta_auctionSnapshot.delta.latestAuction.priceDecay,
            b: priceDecay
        });

        assertEq({
            err: "/// THEN: incorrect details.priceSlippage",
            a: delta_auctionSnapshot.delta.latestAuction.priceSlippage,
            b: priceSlippage
        });

        assertEq({
            err: "/// THEN: incorrect details.expiry",
            a: delta_auctionSnapshot.delta.latestAuction.expiry,
            b: expiry
        });

        assertEq({
            err: "/// THEN: incorrect tokenSell deposited",
            a: delta_auctionSnapshot.delta.fxbSnapshot.balanceOf,
            b: amountListed
        });

        assertEq({
            err: "/// THEN: incorrect tokenBuy deposited",
            a: delta_auctionSnapshot.delta.fraxSnapshot.balanceOf,
            b: 0
        });

        assertEq({
            err: "/// THEN: incorrect amountExcessBuy",
            a: delta_auctionSnapshot.end.latestAuction.amountExcessBuy,
            b: 0
        });

        assertEq({
            err: "/// THEN: incorrect amountExcessSell",
            a: delta_auctionSnapshot.end.latestAuction.amountExcessSell,
            b: 0
        });
    }

    function test_StartAuction_WithdrawAnyAvailableTokens_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        uint256 amountExcessBuy = amountListed / 4;
        uint256 amountExcessSell = amountListed * 3;
        address timelock = iAuction.timelockAddress();

        /// GIVEN: the auction has a pre-existing balance of buy/sellToken
        // buyToken
        _mintFraxTo(auction, amountExcessBuy);

        // sellToken
        _mintFraxTo(timelock, amountExcessSell);
        vm.startPrank(timelock);
        iFrax.approve(fxb, amountExcessSell);
        iFxb.mint(auction, amountExcessSell);
        vm.stopPrank();

        //==============================================================================
        // Act
        //==============================================================================
        SlippageAuctionStorageSnapshot memory initial_auctionSnapshot = slippageAuctionStorageSnapshot(iAuction);
        AccountStorageSnapshot memory initial_timelockSnapshot = accountStorageSnapshot(timelock, iFrax, iFxb);

        /// WHEN: timelock starts the auction with properly formed params
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
            err: "/// THEN: tokenSell not withdrawn",
            a: delta_auctionSnapshot.end.fxbSnapshot.balanceOf,
            b: amountListed
        });

        assertEq({
            err: "/// THEN: tokenBuy not withdrawn",
            a: delta_auctionSnapshot.delta.fraxSnapshot.balanceOf,
            b: amountExcessBuy
        });

        assertEq({
            err: "/// THEN: excess tokenSell not received",
            a: delta_timelockSnapshot.delta.fxbSnapshot.balanceOf,
            b: amountExcessSell
        });

        assertEq({
            err: "/// THEN: excess tokenBuy not received",
            a: delta_timelockSnapshot.delta.fraxSnapshot.balanceOf,
            b: amountExcessBuy
        });

        assertEq({
            err: "/// THEN: incorrect amountExcessBuy",
            a: delta_auctionSnapshot.delta.latestAuction.amountExcessBuy,
            b: amountExcessBuy
        });

        assertEq({
            err: "/// THEN: incorrect amountExcessSell",
            a: delta_auctionSnapshot.delta.latestAuction.amountExcessSell,
            b: amountExcessSell
        });
    }

    function test_StartAuction_LastAuctionStillActive_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: an auction has been started
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

        /// GIVEN: several blocks have passed
        mineBlocks(100);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: tester tries to start another auction
        address _timelockAddress = iAuction.timelockAddress();
        _mintFraxTo(_timelockAddress, amountListed);

        vm.startPrank(_timelockAddress);
        iFrax.approve(fxb, amountListed);
        iFxb.mint(_timelockAddress, amountListed);
        iFxb.approve(auction, amountListed);
        vm.expectRevert(SlippageAuction.LastAuctionStillActive.selector);
        iAuction.startAuction(
            SlippageAuction.StartAuctionParams({
                amountListed: amountListed,
                priceStart: priceStart,
                priceMin: priceMin,
                priceDecay: priceDecay,
                priceSlippage: priceSlippage,
                expiry: expiry
            })
        );

        /// THEN: we expect the function to revert with LastAuctionStillActive()
    }

    function test_StartAuction_Expired_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: starting an auction with expiry in the past
        vm.prank(iAuction.timelockAddress());
        vm.expectRevert(SlippageAuction.Expired.selector);
        iAuction.startAuction(
            SlippageAuction.StartAuctionParams({
                amountListed: amountListed,
                priceStart: priceStart,
                priceMin: priceMin,
                priceDecay: priceDecay,
                priceSlippage: priceSlippage,
                expiry: uint32(block.timestamp - 1 days)
            })
        );

        /// THEN: we expect the function to revert with Expired()
    }

    function test_StartAuction_AmountListedTooLow_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: starting an auction with too few tokens to sell
        hoax(iAuction.timelockAddress());
        vm.expectRevert(SlippageAuction.AmountListedTooLow.selector);
        iAuction.startAuction(
            SlippageAuction.StartAuctionParams({
                amountListed: 1e8 - 1,
                priceStart: priceStart,
                priceMin: priceMin,
                priceDecay: priceDecay,
                priceSlippage: priceSlippage,
                expiry: expiry
            })
        );

        /// THEN: We should expect a revert with AmountListedTooLow()
    }

    function test_StartAuction_PriceStartLessThanPriceMin_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: starting an auction with the starting price less than minimum price
        hoax(iAuction.timelockAddress());
        vm.expectRevert(SlippageAuction.PriceStartLessThanPriceMin.selector);
        iAuction.startAuction(
            SlippageAuction.StartAuctionParams({
                amountListed: amountListed,
                priceStart: priceMin - 1,
                priceMin: priceMin,
                priceDecay: priceDecay,
                priceSlippage: priceSlippage,
                expiry: expiry
            })
        );

        /// THEN: We should expect a revert with PriceStartLessThanPriceMin()
    }

    function test_StartAuction_PriceMinAndSlippageBothZero_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: starting an auction with price slippage >= 100%
        hoax(iAuction.timelockAddress());
        vm.expectRevert(SlippageAuction.PriceMinAndSlippageBothZero.selector);
        iAuction.startAuction(
            SlippageAuction.StartAuctionParams({
                amountListed: amountListed,
                priceStart: priceStart,
                priceMin: 0,
                priceDecay: priceDecay,
                priceSlippage: 0,
                expiry: expiry
            })
        );

        /// THEN: We should expect a revert with PriceMinAndSlippageBothZero()
    }

    function test_StartAuction_CallerNotTimelock_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: starting an auction as tester
        vm.startPrank(tester);
        vm.expectRevert();
        iAuction.startAuction(
            SlippageAuction.StartAuctionParams({
                amountListed: amountListed,
                priceStart: priceStart,
                priceMin: priceMin,
                priceDecay: priceDecay,
                priceSlippage: priceSlippage,
                expiry: expiry
            })
        );

        /// THEN: reverts
    }
}
