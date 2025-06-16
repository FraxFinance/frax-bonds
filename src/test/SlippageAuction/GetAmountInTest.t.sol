// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract GetAmountInTest is SwapHelper {
    function setUp() public {
        defaultSetup();

        /// BACKGROUND: deploy one bond
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + 75 days);

        /// BACKGROUND: an auction has been deployed by TIMELOCK
        (iAuction, auction) = _auctionFactory_createAuctionContract({ _tokenBuy: frax, _tokenSell: fxb });

        /// GIVEN: auction started
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

        /// GIVEN: a basic amountOut
        amountOut = 1e18;
    }

    function test_GetAmountIn_WithoutDelay_succeeds() public {
        /// BACKGROUND: calling getAmountIn the same time the auction is created

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: calculating the amounts based on a swap amount
        amountIn = iAuction.getAmountOut(amountOut, frax);

        //==============================================================================
        // Act
        //==============================================================================

        AccountStorageSnapshot memory initial_testerAccountSnapshot = accountStorageSnapshot(tester, iFrax, iFxb);

        /// WHEN: tester swaps
        startHoax(tester);
        iFrax.approve(auction, amountIn);
        iAuction.swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: amountIn,
            path: new address[](0),
            to: tester,
            deadline: block.timestamp + 1
        });

        DeltaAccountStorageSnapshot memory delta_testerAccountSnapshot = deltaAccountStorageSnapshot(
            initial_testerAccountSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "/// THEN: incorrect amount received",
            a: delta_testerAccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: amountOut
        });
    }

    function test_GetAmountIn_WithDelay_succeeds() public {
        /// BACKGROUND: calling getAmountIn shortly after the auction is created

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: fast-fwd
        mineBlocksBySecond(1 days);

        /// GIVEN: calculating the amountIn based on a swap amount
        amountIn = iAuction.getAmountOut(amountOut, frax);

        //==============================================================================
        // Act
        //==============================================================================

        AccountStorageSnapshot memory initial_testerAccountSnapshot = accountStorageSnapshot(tester, iFrax, iFxb);

        /// WHEN: tester swaps
        startHoax(tester);
        iFrax.approve(auction, amountIn);
        iAuction.swapTokensForExactTokens({
            amountOut: amountOut,
            amountInMax: amountIn,
            path: new address[](0),
            to: tester,
            deadline: block.timestamp + 1
        });

        DeltaAccountStorageSnapshot memory delta_testerAccountSnapshot = deltaAccountStorageSnapshot(
            initial_testerAccountSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "/// THEN: incorrect amount received",
            a: delta_testerAccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: amountOut
        });
    }

    function test_GetAmountIn_InvalidTokenOut_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: calling getAmountIn with a token other than tokenSell
        vm.expectRevert(SlippageAuction.InvalidTokenOut.selector);
        iAuction.getAmountIn(1e18, frax);

        /// THEN: reverts
    }
}
