// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import "../BaseTest.t.sol";

abstract contract AuctionHelper is BaseTest {
    function _auction_startAuction(
        SlippageAuction _iAuction,
        SlippageAuction.StartAuctionParams memory _params
    ) public {
        address _timelock = _iAuction.timelockAddress();
        _mintFraxTo(_timelock, _params.amountListed);
        vm.startPrank(_timelock);
        IERC20(_iAuction.TOKEN_BUY()).approve(_iAuction.TOKEN_SELL(), _params.amountListed);
        FXB(_iAuction.TOKEN_SELL()).mint(_timelock, _params.amountListed);
        FXB(_iAuction.TOKEN_SELL()).approve(address(_iAuction), _params.amountListed);
        _iAuction.startAuction(_params);
        vm.stopPrank();
    }
}
