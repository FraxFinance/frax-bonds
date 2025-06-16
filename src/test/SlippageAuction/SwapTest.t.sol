// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract SwapTest is SwapHelper {
    function setUp() public virtual {
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

    function test_Swap_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: values based on some arbitrary amountOut
        amountOut = amountListed / 8;
        (amountIn, , postPriceSlippage) = iAuction.getAmountIn({ amountOut: amountOut });

        //==============================================================================
        // Act
        //==============================================================================

        SlippageAuctionStorageSnapshot memory initial_auctionSnapshot = slippageAuctionStorageSnapshot(iAuction);
        AccountStorageSnapshot memory initial_buyerSnapshot = accountStorageSnapshot(buyer1, iFrax, iFxb);

        /// WHEN: Buyer swaps a given amount
        startHoax(buyer1);
        iFrax.transfer(auction, amountIn);
        iAuction.swap({ amount0Out: 0, amount1Out: amountOut, to: buyer1, data: new bytes(0) });

        _test_Swap_assertions(initial_auctionSnapshot, initial_buyerSnapshot);
    }

    function test_Swap_excessFxb_reverts() public {
        /// BACKGROUND: fxb is donated to the auction and cannot be withdrawn by a swapper

        //==============================================================================
        // Arrange
        //==============================================================================

        uint256 amountExcess = 1e18;

        // GIVEN: user has donated fxb to the auction
        _mintFraxTo(buyer1, amountExcess);
        vm.startPrank(buyer1);
        iFrax.approve(fxb, amountExcess);
        iFxb.mint(auction, amountExcess);
        vm.stopPrank();

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: buyer attempts to swap to get more than what is for sale
        (amountIn, , ) = iAuction.getAmountInMax();
        (amountOut, , ) = iAuction.getAmountOut({ amountIn: amountIn, _revertOnOverAmountLeft: true });

        // Increment amountOut and swap double the amountIn
        ++amountOut;
        amountIn *= 2;
        _mintFraxTo(buyer1, amountIn);

        vm.startPrank(buyer1);
        iFrax.transfer(auction, amountIn);
        vm.expectRevert(SlippageAuction.InsufficientTokenSellsAvailable.selector);
        iAuction.swap({ amount0Out: 0, amount1Out: amountOut, to: buyer1, data: new bytes(0) });

        /// THEN: reverts
    }

    function test_Swap_ExcessiveTokenBuyOut_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: buyer attempts to receive FRAX from the auction
        hoax(buyer1);
        bytes memory errorMsg = abi.encodeWithSelector(SlippageAuction.ExcessiveTokenBuyOut.selector, 0, 1);
        vm.expectRevert(errorMsg);
        iAuction.swap({ amount0Out: 1, amount1Out: 0, to: buyer1, data: new bytes(0) });

        /// THEN: reverts
    }

    function test_Swap_InsufficientOutputAmount_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: buyer attempts to swap and receive 0 FXB
        hoax(buyer1);
        bytes memory errorMsg = abi.encodeWithSelector(SlippageAuction.InsufficientOutputAmount.selector, 1, 0);
        vm.expectRevert(errorMsg);
        iAuction.swap({ amount0Out: 0, amount1Out: 0, to: buyer1, data: new bytes(0) });

        /// THEN: reverts
    }

    function test_Swap_InsufficientInputAmount_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: values based on some arbitrary amountOut
        amountOut = amountListed / 8;
        (amountIn, , ) = iAuction.getAmountIn({ amountOut: amountOut });

        /// GIVEN: attempt to get 1 more unit of amountIn than allowed
        uint256 amountInOneLess = amountIn - 1;

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: Buyer swaps a given amount greater than what they should receive
        startHoax(buyer1);
        iFrax.transfer(auction, amountInOneLess);

        bytes memory errorMsg = abi.encodeWithSelector(
            SlippageAuction.InsufficientInputAmount.selector,
            amountIn,
            amountInOneLess
        );
        vm.expectRevert(errorMsg);
        iAuction.swap({ amount0Out: 0, amount1Out: amountOut, to: buyer1, data: new bytes(0) });

        /// THEN: reverts
    }

    function test_Swap_InputAmountZero_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: swapping a small amount out
        amountOut = 1;

        /// GIVEN: auction has received enough frax to swap all tokens
        (uint256 amountInMax, , ) = iAuction.getAmountInMax();
        _mintFraxTo(auction, amountInMax);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: Buyer swaps an amount where the invariant rounds down to zero
        startHoax(buyer1);
        vm.expectRevert(SlippageAuction.InputAmountZero.selector);
        iAuction.swap({ amount0Out: 0, amount1Out: amountOut, to: buyer1, data: new bytes(0) });
    }
}
