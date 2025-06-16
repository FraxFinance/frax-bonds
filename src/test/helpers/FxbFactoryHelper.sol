// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import "../BaseTest.t.sol";

abstract contract FxbFactoryHelper is BaseTest {
    function _fxbFactory_createFxbContract(uint256 _maturityTimestamp) public returns (FXB _iFxb, address _fxb) {
        hoax(Constants.Mainnet.FXB_TIMELOCK);
        (_fxb, ) = iFxbFactory.createFxbContract(_maturityTimestamp);
        _iFxb = FXB(_fxb);
    }
}
