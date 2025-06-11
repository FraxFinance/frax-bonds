// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract SwapTokensForExactTokensTest is SwapHelper {
    function setUp() public {
        defaultSetup();

        /// BACKGROUND: deploy one bond
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + 75 days);
        /// BACKGROUND: an auction has been deployed by TIMELOCK
        (iAuction, auction) = _auctionFactory_createAuctionContract({ _tokenBuy: frax, _tokenSell: fxb });

        /// BACKGROUND: the auction has been started
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
    }

    function test_SwapTokensForExactTokens_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: values based on some arbitrary amountIn
        amountOut = amountListed / 7;
        (amountIn, , postPriceSlippage) = iAuction.getAmountIn({ amountOut: amountOut });

        //==============================================================================
        // Act
        //==============================================================================

        SlippageAuctionStorageSnapshot memory initial_auctionSnapshot = slippageAuctionStorageSnapshot(iAuction);
        AccountStorageSnapshot memory initial_buyerSnapshot = accountStorageSnapshot(buyer1, iFrax, iFxb);

        /// WHEN: buyer swaps exact tokens for tokens
        startHoax(buyer1);
        iFrax.approve(auction, amountIn);
        iAuction.swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: amountIn,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp + 1 days
        });

        //==============================================================================
        // Assert
        //==============================================================================

        _test_Swap_assertions(initial_auctionSnapshot, initial_buyerSnapshot);
    }

    function test_SwapTokensForExactTokens_Expired_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: some arbitrary amountOut
        amountOut = 1;

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user attempts to swap with a timestamp in the past
        hoax(buyer1);
        vm.expectRevert(SlippageAuction.Expired.selector);
        iAuction.swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: type(uint256).max,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp - 1 days
        });

        /// THEN: reverts
    }

    function test_SwapTokensForExactTokens_ExcessiveInputAmount_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: values based on some arbitrary amountIn
        amountOut = amountListed / 9;
        (amountIn, , postPriceSlippage) = iAuction.getAmountIn({ amountOut: amountOut });

        /// GIVEN: user provides 1 unit less of amountOut than expected
        uint256 amountOutOneLess = amountOut - 1;
        (uint256 amountInActual, , ) = iAuction.getAmountIn({ amountOut: amountOutOneLess });

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: buyer attempts to swap for more tokens than they've given
        startHoax(buyer1);
        iFrax.approve(auction, amountOutOneLess);

        bytes memory errorMsg = abi.encodeWithSelector(
            SlippageAuction.ExcessiveInputAmount.selector,
            amountInActual,
            amountIn
        );
        vm.expectRevert(errorMsg);
        iAuction.swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: amountInActual,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp + 1 days
        });

        /// THEN: reverts
    }
}
