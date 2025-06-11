// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../../helpers/SwapHelper.sol";

contract FuzzGetAmountOutTest is SwapHelper {
    using SafeCast for *;

    function setUp() public {
        defaultSetup();

        /// BACKGROUND: deploy one bond
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + 75 days);
        /// BACKGROUND: an auction has been deployed by TIMELOCK
        (iAuction, auction) = _auctionFactory_createAuctionContract({ _tokenBuy: frax, _tokenSell: fxb });
    }

    function testFuzz_GetAmountOut(uint256 _amountListed, uint256 _amountIn1, uint256 _amountIn2) public {
        /// BACKGROUND: buyer1 swaps for amountIn1, buyer2 swaps for amountIn2

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: amountListed is in acceptable range
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

        /// GIVEN: both amounts swapped > 0 and buyer1 does not buy the whole lot
        //  (Should be dust as we are auctioning 18-decimal tokens with low value per 1e18)
        (uint256 amountInMax, , ) = iAuction.getAmountInMax();
        vm.assume(_amountIn1 > 1e6 && _amountIn2 > 1e6);
        vm.assume(_amountIn1 < amountInMax / 1e6);
        vm.assume(_amountIn2 < amountInMax / 1e6);

        //==============================================================================
        // Act
        //==============================================================================

        AccountStorageSnapshot memory initial_buyer1AccountSnapshot = accountStorageSnapshot(buyer1, iFrax, iFxb);
        AccountStorageSnapshot memory initial_buyer2AccountSnapshot = accountStorageSnapshot(buyer2, iFrax, iFxb);

        /// WHEN: buyer1 swaps some tokens
        vm.startPrank(buyer1);
        (uint256 amountOut1Expected, , ) = iAuction.getAmountOut({
            amountIn: _amountIn1,
            _revertOnOverAmountLeft: true
        });

        iFrax.approve(auction, _amountIn1);
        uint256[] memory amounts = iAuction.swapExactTokensForTokens({
            amountIn: _amountIn1,
            amountOutMin: amountOut1Expected,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp + 1 days
        });
        uint256 amountOut1Actual = amounts[1];

        vm.stopPrank();

        /// GIVEN: buyer2 buys up to the whole lot
        (amountInMax, , ) = iAuction.getAmountInMax();
        vm.assume(_amountIn2 < amountInMax);

        /// WHEN: buyer2 swaps for the remaining tokens
        vm.startPrank(buyer2);
        (uint256 amountOut2Expected, , ) = iAuction.getAmountOut({
            amountIn: _amountIn2,
            _revertOnOverAmountLeft: true
        });

        iFrax.approve(auction, _amountIn2);
        amounts = iAuction.swapExactTokensForTokens({
            amountIn: _amountIn2,
            amountOutMin: amountOut2Expected,
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

        assertEq({
            err: "/// THEN: amountOut1Expected != amountOut1Actual",
            a: amountOut1Expected,
            b: amountOut1Actual
        });

        assertEq({
            err: "/// THEN: amountOut2Expected != amountOut2Actual",
            a: amountOut2Expected,
            b: amountOut2Actual
        });

        assertEq({
            err: "/// THEN: buyer1 amount received incorrect",
            a: delta_buyer1AccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: amountOut1Actual
        });

        assertEq({
            err: "/// THEN: buyer2 amount received incorrect",
            a: delta_buyer2AccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: amountOut2Actual
        });
    }
}
