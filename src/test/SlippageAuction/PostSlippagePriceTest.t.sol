// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract PostSlippagePriceTest is SwapHelper {
    function setUp() public {
        defaultSetup();

        /// BACKGROUND: deploy one bond
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + 75 days);

        /// BACKGROUND: an auction has been deployed by TIMELOCK
        (iAuction, auction) = _auctionFactory_createAuctionContract({ _tokenBuy: frax, _tokenSell: fxb });

        /// GIVEN: start price is 0.95
        /// GIVEN: priceDecay is 0.01e18 (1c) per day
        _auction_startAuction(
            iAuction,
            SlippageAuction.StartAuctionParams({
                amountListed: amountListed,
                priceStart: priceStart,
                priceMin: priceMin,
                priceDecay: uint64(uint256(0.01e18) / 1 days), // 1c per day
                priceSlippage: priceSlippage,
                expiry: expiry
            })
        );

        /// GIVEN: a basic amountOut
        amountOut = 1e18;
    }

    function test_PostSlippagePrice_succeeds() public {
        /// BACKGROUND: once we have reached the priceMin, we get the same postSlippagePrice
        ///             across functions.

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: fast-fwd
        mineBlocksBySecond(6 days);
        assertEq({ err: "Current price != minPrice", a: iAuction.getPreSlippagePrice(), b: priceMin });

        //==============================================================================
        // Act
        //==============================================================================

        (, , uint256 postPriceSlippageIn) = iAuction.getAmountIn(amountOut);
        (, , uint256 postPriceSlippageOut) = iAuction.getAmountOut(amountIn, false);

        //==============================================================================
        // Assert
        //==============================================================================

        assertApproxEqRel({
            err: "/// THEN: postSlippagePrice incorrect",
            a: postPriceSlippageIn,
            b: postPriceSlippageOut,
            maxPercentDelta: 1e15
        });
    }
}
