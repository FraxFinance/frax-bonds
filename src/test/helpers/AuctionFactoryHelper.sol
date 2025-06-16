// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import "../BaseTest.t.sol";

abstract contract AuctionFactoryHelper is BaseTest {
    function _auctionFactory_createAuctionContract(
        address _tokenBuy,
        address _tokenSell
    ) internal returns (SlippageAuction _iAuction, address _auction) {
        return
            _auctionFactory_createAuctionContract(
                Constants.Mainnet.FXB_TIMELOCK,
                iAuctionFactory,
                _tokenBuy,
                _tokenSell
            );
    }

    function _auctionFactory_createAuctionContract(
        address _deployer,
        SlippageAuctionFactory _iAuctionFactory,
        address _tokenBuy,
        address _tokenSell
    ) internal returns (SlippageAuction _iAuction, address _auction) {
        startHoax(_deployer);
        IERC20(_tokenSell).approve(address(_iAuctionFactory), type(uint256).max);
        _auction = _iAuctionFactory.createAuctionContract(_deployer, _tokenBuy, _tokenSell);
        _iAuction = SlippageAuction(_auction);
        vm.stopPrank();
    }
}
