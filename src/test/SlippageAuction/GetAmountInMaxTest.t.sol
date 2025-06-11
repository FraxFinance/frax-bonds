// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract GetAmountInMaxTest is SwapHelper {
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
    }

    function test_GetAmountInMax_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: calculating the amounts based on the max swap amount
        (amountIn, , ) = iAuction.getAmountInMax();
        (amountOut, , ) = iAuction.getAmountOut({ amountIn: amountIn, _revertOnOverAmountLeft: true });

        assertEq({ err: "/// THEN: amountIn incorrect", a: amountOut, b: amountListed });
    }

    function test_GetAmountInMax_WithoutDelay_succeeds() public {
        /// BACKGROUND: calling getAmountInMax the same time the auction is created

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: calculating the amounts based on the max swap amount
        (amountIn, , ) = iAuction.getAmountInMax();
        amountOut = amountListed;

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

    function test_GetAmountInMax_WithDelay_succeeds() public {
        /// BACKGROUND: calling getAmountInMax shortly after the auction is created

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: fast-fwd
        mineBlocksBySecond(1 days);

        /// GIVEN: calculating the amounts based the max swap amount
        (amountIn, , ) = iAuction.getAmountInMax();
        amountOut = amountListed;

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
}
