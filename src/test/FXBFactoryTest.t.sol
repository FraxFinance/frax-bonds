// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "./BaseTest.t.sol";
import { SigUtils } from "./utils/SigUtils.sol";
import { FxbFactoryHelper } from "./helpers/FxbFactoryHelper.sol";

contract FXBFactoryTest is BaseTest, FxbFactoryHelper {
    function setUp() public {
        /// BACKGROUND: Contracts are deployed
        defaultSetup();

        // Initial state checks
        assertEq(iFxbFactory.fxbsLength(), 4, "/// GIVEN: There should be 4 pre-existing bonds");
        assertEq(iFxbFactory.token(), Constants.Mainnet.FRAX_ERC20);

        (uint256 major, uint256 minor, uint256 patch) = iFxbFactory.version();
        assertEq({ err: "/// THEN: major incorrect", a: major, b: 2 });
        assertEq({ err: "/// THEN: minor incorrect", a: minor, b: 0 });
        assertEq({ err: "/// THEN: patch incorrect", a: patch, b: 0 });
    }

    function test_FxbsLength_succeeds() public {
        /// GIVEN: There are 2 bonds deployed
        _fxbFactory_createFxbContract(block.timestamp + 75 days);
        _fxbFactory_createFxbContract(block.timestamp + 99 days);

        /// WHEN: we check the length of fxbs
        /// THEN: we expect the length to be 6
        assertEq(iFxbFactory.fxbsLength(), 6, "There should be 2 new bonds");
    }

    function _createFxbContractAndAssert(uint256 duration) internal {
        uint256 coercedTimestamp = (duration / 1 days) * 1 days;
        uint256 bondsLengthBefore = iFxbFactory.fxbsLength();
        assertFalse(iFxbFactory.isTimestampFxb(coercedTimestamp));

        /// WHEN: we create an fxb contract
        (iFxb, fxb) = _fxbFactory_createFxbContract(duration);

        /// THEN: Assert
        assertEq(iFxbFactory.fxbsLength(), bondsLengthBefore + 1, "/// THEN: fxbs not appended");
        assertTrue(iFxbFactory.isFxb(fxb), "/// THEN: isFxb not updated");
        assertTrue(iFxbFactory.isTimestampFxb(coercedTimestamp), "/// THEN: isTimestampFxb not updated");
    }

    function test_CreateFxbContract_CreateMany_succeeds() public {
        // Create bonds with various dates
        /// WHEN: we create bonds with various dates
        _createFxbContractAndAssert(block.timestamp + 30 days);
        _createFxbContractAndAssert(block.timestamp + 75 days);
        _createFxbContractAndAssert(block.timestamp + 99 days);
        _createFxbContractAndAssert(block.timestamp + 141 days);
        _createFxbContractAndAssert(block.timestamp + 150 days);
        _createFxbContractAndAssert(block.timestamp + 180 days);
        _createFxbContractAndAssert(block.timestamp + 237 days);
        _createFxbContractAndAssert(block.timestamp + 240 days);
        _createFxbContractAndAssert(block.timestamp + 270 days);
        _createFxbContractAndAssert(block.timestamp + 325 days);
        _createFxbContractAndAssert(block.timestamp + 336 days);
        _createFxbContractAndAssert(block.timestamp + 360 days);

        /// THEN: there is no revert
    }

    function test_CreateFxbContract_BondMaturityAlreadyExists_reverts() public {
        /// GIVEN: a bond with a maturity of 90 days is created
        _fxbFactory_createFxbContract(block.timestamp + 90 days);

        /// WHEN: we try to create a bond with a maturity of 90 days
        startHoax(Constants.Mainnet.FXB_TIMELOCK);
        vm.expectRevert(FXBFactory.BondMaturityAlreadyExists.selector);
        iFxbFactory.createFxbContract(block.timestamp + 90 days);

        /// THEN: reverts
    }

    function test_CreateFxbContract_BondMaturityAlreadyExpired_reverts() public {
        // WHEN: we create a bond where the maturity timestamp is before the current timestamp
        uint256 maturityTimestamp = (block.timestamp / 1 days) * 1 days;
        assertLt(maturityTimestamp, block.timestamp);

        vm.expectRevert(FXBFactory.BondMaturityAlreadyExpired.selector);
        _fxbFactory_createFxbContract(block.timestamp);

        /// THEN: reverts
    }

    function test_CreateFxbContract_CallerNotTimelock_reverts() public {
        /// WHEN: we try to create a bond as tester
        hoax(tester);
        vm.expectRevert();
        iFxbFactory.createFxbContract(block.timestamp + 90 days);

        /// THEN: reverts
    }

    function test_SetToken_succeeds() public {
        /// GIVEN: a new token address
        address newToken = address(0x12345);
        /// WHEN: we set the new token address
        startHoax(Constants.Mainnet.FXB_TIMELOCK);
        iFxbFactory.setToken(newToken);
        /// THEN: the token address is updated
        assertEq(iFxbFactory.token(), newToken, "/// THEN: token address not updated");
    }

    function test_SetToken_CallerNotTimelock_reverts() public {
        /// GIVEN: a new token address
        address newToken = address(0x12345);
        /// WHEN: we try to set the new token address as tester
        hoax(tester);
        vm.expectRevert();
        iFxbFactory.setToken(newToken);

        /// THEN: reverts
    }

    function test_UpgradeFactory_succeeds() public {
        /// GIVEN: a new implementation
        address newImplementation = address(new UpgradedFXBFactory());

        /// WHEN: we upgrade the factory
        hoax(proxyAdmin);
        ITransparentUpgradeableProxy(fxbFactory).upgradeToAndCall(newImplementation, "");

        /// THEN: the implementation is updated
        assertTrue(UpgradedFXBFactory(fxbFactory).foo(), "/// THEN: implementation not updated");
    }
}

interface ITransparentUpgradeableProxy {
    /// @dev See {UUPSUpgradeable-upgradeToAndCall}
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
    function changeAdmin(address newAdmin) external;
}

contract UpgradedFXBFactory is FXBFactory {
    function foo() external pure returns (bool) {
        return true;
    }
}
