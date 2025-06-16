// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../BaseTest.t.sol";
import { FxbFactoryHelper } from "./FxbFactoryHelper.sol";
import { AuctionFactoryHelper } from "./AuctionFactoryHelper.sol";
import { AuctionHelper } from "./AuctionHelper.sol";

/// @dev Inheritable contract for all Swap tests
abstract contract SwapHelper is BaseTest, FxbFactoryHelper, AuctionFactoryHelper, AuctionHelper {
    using SafeCast for *;

    uint256 amountIn;
    uint256 amountOut;
    uint256 postPriceSlippage;

    function _test_Swap_assertions(
        SlippageAuctionStorageSnapshot memory _initial_auctionSnapshot,
        AccountStorageSnapshot memory _initial_buyerSnapshot
    ) internal {
        /// BACKGROUND: calculate ending balance changes
        DeltaSlippageAuctionStorageSnapshot memory delta_auctionSnapshot = deltaSlippageAuctionStorageSnapshot(
            _initial_auctionSnapshot
        );
        DeltaAccountStorageSnapshot memory delta_buyerSnapshot = deltaAccountStorageSnapshot(_initial_buyerSnapshot);

        //==============================================================================
        // Assert
        //==============================================================================

        // Detail struct

        assertEq({
            err: "/// THEN: detail.amountLeft incorrect",
            a: delta_auctionSnapshot.delta.latestAuction.amountLeft,
            b: amountOut
        });

        assertEq({
            err: "/// THEN: detail.tokenBuyReceived incorrect",
            a: delta_auctionSnapshot.delta.latestAuction.tokenBuyReceived,
            b: amountIn
        });

        assertEq({
            err: "/// THEN: detail.priceLast incorrect",
            a: delta_auctionSnapshot.delta.latestAuction.priceLast,
            b: stdMath.delta(postPriceSlippage, priceStart)
        });

        assertEq({
            err: "/// THEN: detail.lastBuyTime incorrect",
            a: delta_auctionSnapshot.end.latestAuction.lastBuyTime,
            b: block.timestamp
        });

        // Ensure an untouched value in the struct remains constant
        assertEq({
            err: "/// THEN: detail struct storage changed",
            a: delta_auctionSnapshot.delta.latestAuction.amountListed,
            b: 0
        });

        // Balances

        assertEq({
            err: "/// THEN: tokenBuy balance of auction incorrect",
            a: delta_auctionSnapshot.delta.fraxSnapshot.balanceOf,
            b: amountIn
        });

        assertEq({
            err: "/// THEN: tokenBuy balance of buyer incorrect",
            a: delta_buyerSnapshot.delta.fraxSnapshot.balanceOf,
            b: amountIn
        });

        assertEq({
            err: "/// THEN: tokenSell balance of auction incorrect",
            a: delta_auctionSnapshot.delta.fxbSnapshot.balanceOf,
            b: amountOut
        });

        assertEq({
            err: "/// THEN: tokenSell balance of buyer incorrect",
            a: delta_buyerSnapshot.delta.fxbSnapshot.balanceOf,
            b: amountOut
        });
    }
}
