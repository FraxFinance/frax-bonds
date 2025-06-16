// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../../helpers/SwapHelper.sol";

contract FuzzGetAmountInMaxTest is SwapHelper {
    using SafeCast for *;

    function setUp() public {
        defaultSetup();

        /// BACKGROUND: deploy one bond
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + 75 days);
        /// BACKGROUND: an auction has been deployed by TIMELOCK
        (iAuction, auction) = _auctionFactory_createAuctionContract({ _tokenBuy: frax, _tokenSell: fxb });
    }

    function testFuzz_GetAmountInMax(uint256 _amountListed, uint256 _amountIn1) public {
        /// BACKGROUND: buyer1 swaps for amountspent1, buyer2 buys the remaining lot using `getAmountInMax()`

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: amountListed and amountSpent1 are in acceptable ranges
        _amountListed = bound(_amountListed, 1e8, 1_000_000 * 1e18);

        /// GIVEN: auction started
        _auction_startAuction(
            iAuction,
            SlippageAuction.StartAuctionParams({
                amountListed: uint128(_amountListed),
                priceStart: priceStart,
                priceMin: priceMin,
                priceDecay: priceDecay,
                priceSlippage: priceSlippage,
                expiry: expiry
            })
        );

        /// GIVEN: fast-fwd some time
        mineBlocksBySecond(1 days);

        (uint256 amountInMax, , ) = iAuction.getAmountInMax();
        // Rounding issues - amountIn must be at least 11 units and less than the total amount - 100_000
        //  (Should be dust as we are auctioning 18-decimal tokens with low value per 1e18)
        vm.assume(_amountIn1 > 10 && _amountIn1 < amountInMax / 1e6);

        //==============================================================================
        // Act
        //==============================================================================

        AccountStorageSnapshot memory initial_buyer2AccountSnapshot = accountStorageSnapshot(buyer2, iFrax, iFxb);

        /// WHEN: buyer1 swaps some tokens
        vm.startPrank(buyer1);

        iFrax.approve(auction, _amountIn1);
        uint256[] memory amounts = iAuction.swapExactTokensForTokens({
            amountIn: _amountIn1,
            amountOutMin: 0,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp + 1 days
        });
        uint256 amountOut1 = amounts[1];

        vm.stopPrank();

        /// WHEN: buyer2 swaps for the remaining tokens
        vm.startPrank(buyer2);

        (uint256 amountIn2, , ) = iAuction.getAmountInMax();
        iFrax.approve(auction, amountIn2);
        amounts = iAuction.swapTokensForExactTokens({
            amountOut: _amountListed - amountOut1,
            amountInMax: amountIn2,
            path: new address[](0),
            to: buyer2,
            deadline: block.timestamp + 1 days
        });

        DeltaAccountStorageSnapshot memory delta_buyer2AccountSnapshot = deltaAccountStorageSnapshot(
            initial_buyer2AccountSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        assertApproxEqRel({
            err: "/// THEN: buyer2 has not received the lot",
            a: delta_buyer2AccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: _amountListed - amountOut1,
            maxPercentDelta: 1e6
        });
    }
}
