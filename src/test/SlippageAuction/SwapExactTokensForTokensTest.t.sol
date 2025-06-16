// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract SwapExactTokensForTokensTest is SwapHelper {
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

    function test_SwapExactTokensForTokens_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: values based on some arbitrary amountIn
        amountIn = amountListed / 6;
        (amountOut, , postPriceSlippage) = iAuction.getAmountOut({
            amountIn: amountIn,
            _revertOnOverAmountLeft: false
        });

        assertTrue(amountOut < amountListed, "/// THEN: should not receive the whole lot");

        //==============================================================================
        // Act
        //==============================================================================

        SlippageAuctionStorageSnapshot memory initial_auctionSnapshot = slippageAuctionStorageSnapshot(iAuction);
        AccountStorageSnapshot memory initial_buyerSnapshot = accountStorageSnapshot(buyer1, iFrax, iFxb);

        /// WHEN: buyer swaps exact tokens for tokens
        startHoax(buyer1);
        iFrax.approve(auction, amountIn);
        iAuction.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOut,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp + 1 days
        });

        //==============================================================================
        // Assert
        //==============================================================================

        _test_Swap_assertions(initial_auctionSnapshot, initial_buyerSnapshot);
    }

    function testSwapExactTokensForTokens_AtPriceMin_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: fast-fwd so that current price = min price
        mineBlocksToTimestamp(expiry - 1);
        uint256 price = iAuction.getPreSlippagePrice(iAuction.getLatestAuction());
        assertEq({ err: "/// THEN: current price != priceMin", a: price, b: priceMin });

        /// GIVEN: some arbitrary swap amount
        amountIn = amountListed / 6;
        (amountOut, , postPriceSlippage) = iAuction.getAmountOut({
            amountIn: amountIn,
            _revertOnOverAmountLeft: false
        });
        assertTrue(amountOut > 0, "amountOut == 0");
        assertTrue(postPriceSlippage > priceMin, "price after swap <= priceMin");

        //==============================================================================
        // Act
        //==============================================================================

        SlippageAuctionStorageSnapshot memory initial_auctionSnapshot = slippageAuctionStorageSnapshot(iAuction);
        AccountStorageSnapshot memory initial_buyerSnapshot = accountStorageSnapshot(buyer1, iFrax, iFxb);

        /// WHEN: buyer swaps exact tokens for tokens
        startHoax(buyer1);
        iFrax.approve(auction, amountIn);
        iAuction.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOut,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp + 1
        });

        //==============================================================================
        // Assert
        //==============================================================================

        _test_Swap_assertions(initial_auctionSnapshot, initial_buyerSnapshot);
    }

    function test_SwapExactTokensForTokens_Expired_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: some arbitrary amountIn
        amountIn = 1;

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user attempts to swap with a timestamp in the past
        hoax(buyer1);
        vm.expectRevert(SlippageAuction.Expired.selector);
        iAuction.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp - 1
        });

        /// THEN: reverts
    }

    function test_SwapExactTokensForTokens_InsufficientOutputAmount_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: values based on some arbitrary amountIn
        amountIn = amountListed / 6;
        (amountOut, , postPriceSlippage) = iAuction.getAmountOut({
            amountIn: amountIn,
            _revertOnOverAmountLeft: false
        });

        /// GIVEN: user provides 1 unit less of amountIn than expected
        uint256 amountInOneLess = amountIn - 1;
        (uint256 amountOutActual, , ) = iAuction.getAmountOut({
            amountIn: amountInOneLess,
            _revertOnOverAmountLeft: false
        });

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: buyer attempts to swap for more tokens than they've given
        startHoax(buyer1);
        iFrax.approve(auction, amountInOneLess);

        bytes memory errorMsg = abi.encodeWithSelector(
            SlippageAuction.InsufficientOutputAmount.selector,
            amountOut,
            amountOutActual
        );
        vm.expectRevert(errorMsg);
        iAuction.swapExactTokensForTokens({
            amountIn: amountInOneLess,
            amountOutMin: amountOut,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp + 1 days
        });

        /// THEN: reverts
    }
}
