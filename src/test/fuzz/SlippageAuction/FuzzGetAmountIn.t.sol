// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../../helpers/SwapHelper.sol";

contract FuzzGetAmountInTest is SwapHelper {
    using SafeCast for *;

    function setUp() public {
        defaultSetup();

        /// BACKGROUND: deploy one bond
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + 75 days);
        /// BACKGROUND: an auction has been deployed by TIMELOCK
        (iAuction, auction) = _auctionFactory_createAuctionContract({ _tokenBuy: frax, _tokenSell: fxb });
    }

    function testFuzz_GetAmountIn(uint256 _amountListed, uint256 _amountOut1, uint256 _amountOut2) public {
        /// BACKGROUND: buyer1 swaps for amountIn1, buyer2 swaps for amountIn2

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: amountListed and amountOut are in acceptable ranges
        _amountListed = bound(_amountListed, 1e8, 1_000_000 * 1e18);
        _amountOut1 = bound(_amountOut1, 1e2, _amountListed / 1e2);
        _amountOut2 = bound(_amountOut2, 1e2, _amountListed / 1e2);

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

        //==============================================================================
        // Act
        //==============================================================================

        AccountStorageSnapshot memory initial_buyer1AccountSnapshot = accountStorageSnapshot(buyer1, iFrax, iFxb);
        AccountStorageSnapshot memory initial_buyer2AccountSnapshot = accountStorageSnapshot(buyer2, iFrax, iFxb);

        /// WHEN: buyer1 swaps some tokens
        vm.startPrank(buyer1);
        (uint256 amountIn1Expected, , ) = iAuction.getAmountIn({ amountOut: _amountOut1 });

        iFrax.approve(auction, amountIn1Expected);
        uint256[] memory amounts = iAuction.swapTokensForExactTokens({
            amountOut: _amountOut1,
            amountInMax: amountIn1Expected,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp + 1 days
        });
        uint256 amountOut1Actual = amounts[1];

        vm.stopPrank();

        /// WHEN: buyer2 swaps
        vm.startPrank(buyer2);
        (uint256 amountIn2Expected, , ) = iAuction.getAmountIn({ amountOut: _amountOut2 });

        iFrax.approve(auction, amountIn2Expected);
        amounts = iAuction.swapTokensForExactTokens({
            amountOut: _amountOut2,
            amountInMax: amountIn2Expected,
            path: new address[](0),
            to: buyer2,
            deadline: block.timestamp + 1 days
        });
        uint256 amountOut2Actual = amounts[1];

        DeltaAccountStorageSnapshot memory delta_buyer1AccountSnapshot = deltaAccountStorageSnapshot(
            initial_buyer1AccountSnapshot
        );
        DeltaAccountStorageSnapshot memory delta_buyer2AccountSnapshot = deltaAccountStorageSnapshot(
            initial_buyer2AccountSnapshot
        );

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ err: "/// THEN: _amountOut1 != amountOut1Actual", a: _amountOut1, b: amountOut1Actual });

        assertEq({ err: "/// THEN: _amoutOut2 != amountOut2Actual", a: _amountOut2, b: amountOut2Actual });

        assertEq({
            err: "/// THEN: buyer1 amount received incorrect",
            a: delta_buyer1AccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: _amountOut1
        });

        assertEq({
            err: "/// THEN: buyer2 amount received incorrect",
            a: delta_buyer2AccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: _amountOut2
        });
    }
}
