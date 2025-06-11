// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract GetPreSlippagePriceTest is SwapHelper {
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
    }

    function test_GetPreSlippagePrice_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: 1 day has passed
        mineBlocksBySecond(1 days);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: purchasing 100_000 tokens
        uint256 price = iAuction.getPreSlippagePrice(iAuction.getLatestAuction());

        //==============================================================================
        // Assert
        //==============================================================================

        assertApproxEqRel({
            err: "/// THEN: price should be approximately 1c less",
            a: priceStart - uint256(0.01e18),
            b: price,
            maxPercentDelta: 1e5
        });
    }

    function test_GetPreSlippagePrice_PriceMin_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: Past the expiry
        mineBlocksBySecond(100 days);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: purchasing 100_000 tokens
        uint256 price = iAuction.getPreSlippagePrice(iAuction.getLatestAuction());

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ err: "/// THEN: price should be  equal to the minimum price", a: priceMin, b: price });
    }
}
