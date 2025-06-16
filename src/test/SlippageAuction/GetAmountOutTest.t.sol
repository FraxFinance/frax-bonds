// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract GetAmountOutTest is SwapHelper {
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

    function test_GetAmountOut_WithoutDelay_succeeds() public {
        /// BACKGROUND: calling getAmountOut the same time the auction is created

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: calculating the amounts based on a swap amount
        amountIn = 1e18;
        amountOut = iAuction.getAmountOut(amountIn, frax);

        //==============================================================================
        // Act
        //==============================================================================

        AccountStorageSnapshot memory initial_testerAccountSnapshot = accountStorageSnapshot(tester, iFrax, iFxb);

        /// WHEN: tester swaps
        startHoax(tester);
        iFrax.approve(auction, amountIn);
        iAuction.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOut,
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

    function test_GetAmountOut_WithDelay_succeeds() public {
        /// BACKGROUND: calling getAmountOut shortly after the auction is created

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: fast-fwd
        mineBlocksBySecond(1 days);

        /// GIVEN: calculating the amounts based on a swap amount
        amountIn = 1e18;
        amountOut = iAuction.getAmountOut(amountIn, frax);

        //==============================================================================
        // Act
        //==============================================================================

        AccountStorageSnapshot memory initial_testerAccountSnapshot = accountStorageSnapshot(tester, iFrax, iFxb);

        /// WHEN: tester swaps
        startHoax(tester);
        iFrax.approve(auction, amountIn);
        iAuction.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: amountOut,
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

    function test_GetAmountOut_InvalidTokenIn_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: calling getAmountOut with a token other than tokenBuy
        vm.expectRevert(SlippageAuction.InvalidTokenIn.selector);
        iAuction.getAmountOut(1e18, fxb);

        /// THEN: reverts
    }

    function test_GetAmountOut_RevertOnOverAmountLeftTrue_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user attempts to get 1 unit more than detail.amountLeft
        (amountIn, , ) = iAuction.getAmountInMax();
        ++amountIn;

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user calls getAmountOut to receive more than detail.amountleft
        vm.expectRevert(SlippageAuction.InsufficientTokenSellsAvailable.selector);
        iAuction.getAmountOut({ amountIn: amountIn, _revertOnOverAmountLeft: true });

        /// THEN: reverts
    }

    function test_GetAmountOut_RevertOnOverAmountLeftFalse_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user attempts to get 1 unit more than detail.amountLeft
        (amountIn, , ) = iAuction.getAmountInMax();
        ++amountIn;

        (amountOut, , ) = iAuction.getAmountOut({ amountIn: amountIn, _revertOnOverAmountLeft: false });

        assertEq({ err: "/// THEN: amountOut != amountListed", a: amountOut, b: amountListed });
    }
}
