// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract E2ESlippageAuction is SwapHelper {
    using SafeCast for *;

    uint256 duration = 75 days;

    function setUp() public {
        defaultSetup();

        /// BACKGROUND: deploy one bond
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + duration);
        /// BACKGROUND: an auction has been deployed by TIMELOCK
        (iAuction, auction) = _auctionFactory_createAuctionContract({ _tokenBuy: frax, _tokenSell: fxb });
    }

    function testFuzz_SlippageAuction_E2E_succeeds(
        uint256 _amountListed1,
        uint256 _amountListed2,
        uint256 _amountOut1,
        uint256 _amountOut2,
        uint256 _amountIn1,
        uint32 _fastFwd
    ) public {
        /// BACKGROUND: set variables to reasonable range
        /// @dev: 1e6 range solve precision rounding
        _amountListed1 = bound(_amountListed1, 1e12, 1_000_000 * 1e18);
        _amountListed2 = bound(_amountListed2, 1e12, 1_000_000 * 1e18);
        _amountOut1 = bound(_amountOut1, 1e6, _amountListed1 / 1e5);
        _amountOut2 = bound(_amountOut2, 1e6, _amountListed2 / 1e5);

        _amountIn1 = bound(_amountIn1, 1e6, 1e18);

        /// @dev we fast-fwd twice in auction2, so _fastFwd * 2 cannot be greated than expiry
        vm.assume(_fastFwd < 7 days / 2 && _fastFwd > 1);

        expiry = uint32(block.timestamp + 7 days);

        //==============================================================================
        // Arrange
        //==============================================================================

        SlippageAuctionStorageSnapshot memory initialSnapshot = slippageAuctionStorageSnapshot(iAuction);

        SlippageAuction.StartAuctionParams memory params = SlippageAuction.StartAuctionParams({
            amountListed: uint128(_amountListed1),
            priceStart: priceStart,
            priceMin: priceMin,
            priceDecay: priceDecay,
            priceSlippage: priceSlippage,
            expiry: expiry
        });

        //==============================================================================
        // Act
        //==============================================================================

        // Auction: start 1
        _auction_startAuction({ _iAuction: iAuction, _params: params });

        // User: immediate swap
        vm.startPrank(buyer1);
        (uint256 amountOutExpected, , ) = iAuction.getAmountOut({
            amountIn: _amountIn1,
            _revertOnOverAmountLeft: false
        });
        vm.assume(amountOutExpected < _amountListed1 / 1e6 && amountOutExpected > 1e6);
        iFrax.approve(auction, _amountIn1);
        iAuction.swapExactTokensForTokens({
            amountIn: _amountIn1,
            amountOutMin: amountOutExpected,
            path: new address[](0),
            to: buyer1,
            deadline: block.timestamp + 1
        });
        vm.stopPrank();

        // fast-fwd: block.timestamp < expiry
        mineBlocksBySecond(_fastFwd);

        // User: swap
        vm.startPrank(buyer2);
        (uint256 amountIn1Expected, , ) = iAuction.getAmountIn({ amountOut: _amountOut1 });
        vm.assume(amountIn1Expected > 1e6);
        iFrax.approve(auction, amountIn1Expected);
        iAuction.swapTokensForExactTokens({
            amountOut: _amountOut1,
            amountInMax: amountIn1Expected,
            path: new address[](0),
            to: buyer2,
            deadline: block.timestamp + 1
        });

        // fast-fwd: block.timestamp > expiry
        mineBlocksBySecond(expiry - block.timestamp + 1);

        // User: revert on swap
        vm.expectRevert(SlippageAuction.AuctionExpired.selector);
        iAuction.swapTokensForExactTokens({
            amountOut: _amountOut1,
            amountInMax: 0,
            path: new address[](0),
            to: address(0),
            deadline: block.timestamp + 1
        });
        vm.stopPrank();

        // Auction: end 1
        vm.prank(iAuction.timelockAddress());
        iAuction.stopAuction();

        // Auction: start
        expiry = uint32(block.timestamp + 7 days);
        params.expiry = expiry;
        _auction_startAuction({ _iAuction: iAuction, _params: params });

        // Donate extra buyToken to auction to attract swappers
        _mintFraxTo(auction, _amountListed1);

        // fast-fwd: some arbitrary amount
        mineBlocksBySecond(_fastFwd / 2);

        // Auction: end
        vm.prank(iAuction.timelockAddress());
        iAuction.stopAuction();

        // Auction: start 2
        expiry = uint32(block.timestamp + 7 days);
        params.amountListed = uint128(_amountListed2);
        params.expiry = expiry;
        _auction_startAuction({ _iAuction: iAuction, _params: params });

        // fast-fwd: block.timestamp < expiry
        mineBlocksBySecond(_fastFwd);

        // User: swap
        vm.startPrank(buyer1);
        (uint256 amountIn2Expected, , ) = iAuction.getAmountIn({ amountOut: _amountOut2 });
        vm.assume(amountIn2Expected > 1e6);
        iFrax.approve(auction, amountIn2Expected);
        iAuction.swapTokensForExactTokens({
            amountOut: _amountOut2,
            amountInMax: amountIn2Expected,
            path: new address[](0),
            to: buyer2,
            deadline: block.timestamp + 1
        });
        vm.stopPrank();

        // fast-fwd: block.timestamp < expiry
        mineBlocksBySecond(_fastFwd);

        // Donate extra sellToken to auction
        vm.startPrank(buyer2);
        iFrax.approve(fxb, _amountListed2);
        iFxb.mint(auction, _amountListed2);
        vm.stopPrank();

        // User: swap all
        vm.startPrank(buyer2);
        (uint256 amountIn3Expected, , ) = iAuction.getAmountInMax();
        (uint256 amountOut3Expected, , ) = iAuction.getAmountOut({
            amountIn: amountIn3Expected,
            _revertOnOverAmountLeft: false
        });
        vm.assume(amountIn3Expected > 1e6 && amountOut3Expected > 1e6);
        iFrax.approve(auction, amountIn3Expected);
        iAuction.swapTokensForExactTokens({
            amountOut: amountOut3Expected,
            amountInMax: amountIn3Expected,
            path: new address[](0),
            to: buyer2,
            deadline: block.timestamp + 1
        });
        vm.stopPrank();

        // Auction: end
        vm.prank(iAuction.timelockAddress());
        iAuction.stopAuction();

        //==============================================================================
        // Assert
        //==============================================================================

        DeltaSlippageAuctionStorageSnapshot memory deltaSnapshot = deltaSlippageAuctionStorageSnapshot(initialSnapshot);

        assertEq({ err: "/// THEN: auction still holds FRAX", a: deltaSnapshot.delta.fraxSnapshot.balanceOf, b: 0 });

        assertEq({ err: "/// THEN: auction still holds FXB", a: deltaSnapshot.delta.fxbSnapshot.balanceOf, b: 0 });

        assertEq({ err: "/// THEN: invalid detailsLength", a: deltaSnapshot.delta.detailsLength, b: 3 });
    }
}
