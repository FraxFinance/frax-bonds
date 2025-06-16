// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import "./BaseTest.t.sol";
import { FxbFactoryHelper } from "./helpers/FxbFactoryHelper.sol";
import { FraxBeacon } from "src/contracts/FraxBeacon.sol";

contract FXBTest is BaseTest, FxbFactoryHelper {
    address bob;
    address alice;
    uint256 amount = 2e18;

    function setUp() public {
        /// BACKGROUND: Contracts are deployed
        defaultSetup();

        /// BACKGROUND: a bond is created with now + 90 days maturity
        (iFxb, fxb) = _fxbFactory_createFxbContract(block.timestamp + 90 days);

        bob = labelAndDeal(address(1234), "bob");
        _mintFraxTo(bob, 1000 ether);

        alice = labelAndDeal(address(2345), "alice");
        _mintFraxTo(alice, 1000 ether);
    }

    function test_InitialState_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================
        uint256 startOf2031 = 1_924_992_000; // January 1, 2031 12:00:00 AM
        uint256 startOf2032 = 1_956_528_000; // January 1, 2032 12:00:00 AM

        // GIVEN: we have existing FXBs
        (FXB iFxb2030, ) = _fxbFactory_createFxbContract(startOf2031);
        (FXB iFxb2031, ) = _fxbFactory_createFxbContract(startOf2032);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ err: "/// THEN: iFxb.name() incorrect", a: iFxb.name(), b: "FXB20230721" });
        assertEq({ err: "/// THEN: iFxb.symbol() incorrect", a: iFxb.symbol(), b: "FXB20230721" });

        assertEq({ err: "/// THEN: iFxb2030.name() incorrect", a: iFxb2030.name(), b: "FXB20301231" });
        assertEq({ err: "/// THEN: iFxb2030.symbol() incorrect", a: iFxb2030.symbol(), b: "FXB20301231" });
        assertEq({
            err: "/// THEN: iFxb2030.MATURITY_TIMESTAMP() incorrect",
            a: iFxb2030.MATURITY_TIMESTAMP(),
            b: startOf2031
        });

        assertEq({ err: "/// THEN: iFxb2031.name() incorrect", a: iFxb2031.name(), b: "FXB20311231" });
        assertEq({ err: "/// THEN: iFxb2031.symbol() incorrect", a: iFxb2031.symbol(), b: "FXB20311231" });
        assertEq({
            err: "/// THEN: iFxb2031.MATURITY_TIMESTAMP() incorrect",
            a: iFxb2031.MATURITY_TIMESTAMP(),
            b: startOf2032
        });

        (uint256 major, uint256 minor, uint256 patch) = iFxb.version();
        assertEq({ err: "/// THEN: major incorrect", a: major, b: 2 });
        assertEq({ err: "/// THEN: minor incorrect", a: minor, b: 0 });
        assertEq({ err: "/// THEN: patch incorrect", a: patch, b: 0 });
    }

    function test_IsRedeemable_BeforeMaturity_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: the time is one second before the maturity timestamp
        vm.warp(iFxb.MATURITY_TIMESTAMP() - 1);
        assertEq({
            err: "/// THEN: block.timestamp should be 1 less than maturity timestamp",
            a: block.timestamp,
            b: iFxb.MATURITY_TIMESTAMP() - 1
        });

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: bond is not redeemable
        assertFalse(iFxb.isRedeemable());
    }

    function test_IsRedeemable_BeforeMaturityAsOwner_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: the time is one second before the maturity timestamp
        vm.warp(iFxb.MATURITY_TIMESTAMP() - 1);
        assertEq({
            err: "/// THEN: block.timestamp should be 1 less than maturity timestamp",
            a: block.timestamp,
            b: iFxb.MATURITY_TIMESTAMP() - 1
        });

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: bond is redeemable
        vm.startPrank(iFxbFactory.owner());
        assertTrue(iFxb.isRedeemable());
    }

    function test_IsRedeemable_AtMaturity_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: the time is at the maturity timestamp
        vm.warp(iFxb.MATURITY_TIMESTAMP());
        assertEq({
            err: "/// THEN: block.timestamp should equal maturity timestamp",
            a: block.timestamp,
            b: iFxb.MATURITY_TIMESTAMP()
        });

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: bond is redeemable
        assertTrue(iFxb.isRedeemable());
    }

    function test_OwnerIsRedeemable_AtMaturityAsOwner_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: the time is at the maturity timestamp
        vm.warp(iFxb.MATURITY_TIMESTAMP());
        assertEq({
            err: "/// THEN: block.timestamp should equal maturity timestamp",
            a: block.timestamp,
            b: iFxb.MATURITY_TIMESTAMP()
        });

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: bond is redeemable
        vm.startPrank(iFxbFactory.owner());
        assertTrue(iFxb.isRedeemable());
    }

    function test_Mint_NotApproved_reverts() public {
        /// GIVEN: a user has not approved FRAX
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: a user tries to mint a bond
        hoax(Constants.Mainnet.OPERATOR_ADDRESS);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        iFxb.mint(bob, 1e18);

        /// THEN: we expect the function to revert with ERC20: transfer amount exceeds allowance
    }

    function test_Mint_BeforeMaturity_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================
        // GIVEN: a user has approved FRAX
        hoax(bob);
        iFrax.approve(fxb, amount);

        FxbStorageSnapshot memory initial_fxbSnapshot = fxbStorageSnapshot(iFxb);
        AccountStorageSnapshot memory initial_bobAccountSnapshot = accountStorageSnapshot(bob, iFrax, iFxb);
        AccountStorageSnapshot memory initial_aliceAccountSnapshot = accountStorageSnapshot(alice, iFrax, iFxb);

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: a user tries mints bonds with amount FRAX to another user as the recipient
        hoax(bob);
        iFxb.mint(alice, amount);

        //==============================================================================
        // Assert
        //==============================================================================

        DeltaFxbStorageSnapshot memory delta_fxbSnapshot = deltaFxbStorageSnapshot(initial_fxbSnapshot);
        DeltaAccountStorageSnapshot memory delta_bobAccountSnapshot = deltaAccountStorageSnapshot(
            initial_bobAccountSnapshot
        );
        DeltaAccountStorageSnapshot memory delta_aliceAccountSnapshot = deltaAccountStorageSnapshot(
            initial_aliceAccountSnapshot
        );

        assertEq({
            err: "/// THEN: we expect balance of frax in fxb contract to increase by amount",
            a: delta_fxbSnapshot.delta.fraxSnapshot.balanceOf,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the totalSupply of fxb to increase by amount",
            a: delta_fxbSnapshot.delta.totalSupply,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the frax balance of sender to decrease by amount",
            a: delta_bobAccountSnapshot.delta.fraxSnapshot.balanceOf,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the fxb balance of recipient to increase by amount",
            a: delta_aliceAccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: amount
        });
    }

    function test_Mint_AfterMaturity_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: 6 months have passed (and we are passed maturity)
        mineBlocksBySecond(6 * (30 days));
        assertTrue(iFxb.isRedeemable());

        // GIVEN: a user has approved FRAX
        hoax(bob);
        iFrax.approve(fxb, amount);

        FxbStorageSnapshot memory initial_fxbSnapshot = fxbStorageSnapshot(iFxb);
        AccountStorageSnapshot memory initial_bobAccountSnapshot = accountStorageSnapshot(bob, iFrax, iFxb);
        AccountStorageSnapshot memory initial_aliceAccountSnapshot = accountStorageSnapshot(alice, iFrax, iFxb);

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: a user tries mints bonds with 1e18 FRAX to another user as the recipient
        hoax(bob);
        iFxb.mint(alice, amount);

        //==============================================================================
        // Assert
        //==============================================================================

        DeltaFxbStorageSnapshot memory delta_fxbSnapshot = deltaFxbStorageSnapshot(initial_fxbSnapshot);
        DeltaAccountStorageSnapshot memory delta_bobAccountSnapshot = deltaAccountStorageSnapshot(
            initial_bobAccountSnapshot
        );
        DeltaAccountStorageSnapshot memory delta_aliceAccountSnapshot = deltaAccountStorageSnapshot(
            initial_aliceAccountSnapshot
        );

        assertEq({
            err: "/// THEN: we expect balance of frax in fxb contract to increase by amount",
            a: delta_fxbSnapshot.delta.fraxSnapshot.balanceOf,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the totalSupply of fxb to increase by amount",
            a: delta_fxbSnapshot.delta.totalSupply,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the frax balance of sender to decrease by amount",
            a: delta_bobAccountSnapshot.delta.fraxSnapshot.balanceOf,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the fxb balance of recipient to increase by amount",
            a: delta_aliceAccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: amount
        });
    }

    function test_Burn_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: Approve FRAX to the bond contract (as the operator)
        hoax(Constants.Mainnet.OPERATOR_ADDRESS);
        iFrax.approve(fxb, amount);

        /// GIVEN: Operator has minted the bond to the tester
        hoax(Constants.Mainnet.OPERATOR_ADDRESS);
        iFxb.mint(tester, amount);

        // GIVEN: 6 months have passed (and we are passed maturity)
        mineBlocksBySecond(6 * (30 days));

        // GIVEN: isBondRedeemable returns true
        assertEq(iFxb.isRedeemable(), true, "Make sure the bond is redeemable");

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: the user tries to redeem their full balance
        vm.startPrank(tester);
        uint256 balanceBefore = iFrax.balanceOf(tester);
        iFxb.burn(tester, amount);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ err: "/// THEN: we expect the user to have 0 bond", a: iFxb.balanceOf(tester), b: 0 });
        assertEq({
            err: "/// THEN: we expect the user to have gained amount",
            a: iFrax.balanceOf(tester) - balanceBefore,
            b: amount
        });
    }

    function test_Burn_BeforeMaturityAsOwner_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: Approve FRAX to the bond contract (as the operator)
        vm.startPrank(Constants.Mainnet.OPERATOR_ADDRESS);
        iFrax.approve(fxb, amount);

        /// GIVEN: Operator has minted the bond to the owner
        iFxb.mint(iFxbFactory.owner(), amount);
        vm.stopPrank();

        test_IsRedeemable_BeforeMaturityAsOwner_succeeds();

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: the iFxbFactory.owner() tries to redeem their full balance
        vm.startPrank(iFxbFactory.owner());
        uint256 balanceBefore = iFrax.balanceOf(iFxbFactory.owner());
        iFxb.burn(iFxbFactory.owner(), amount);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "/// THEN: we expect the iFxbFactory.owner() to have 0 bond",
            a: iFxb.balanceOf(iFxbFactory.owner()),
            b: 0
        });
        assertEq({
            err: "/// THEN: we expect the iFxbFactory.owner() to have gained amount",
            a: iFrax.balanceOf(iFxbFactory.owner()) - balanceBefore,
            b: amount
        });
    }

    function test_Burn_BondNotRedeemable_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: Approve FRAX to the bond contract (as the operator)
        hoax(Constants.Mainnet.OPERATOR_ADDRESS);
        iFrax.approve(fxb, amount);

        /// GIVEN: Operator has minted the bond to the tester
        hoax(Constants.Mainnet.OPERATOR_ADDRESS);
        iFxb.mint(tester, amount);

        //==============================================================================
        // Act
        //==============================================================================

        /// GIVEN: the maturity date has not passed
        // WHEN: the user tries to redeem
        vm.startPrank(tester);
        vm.expectRevert(FXB.BondNotRedeemable.selector);
        iFxb.burn(tester, amount);

        /// THEN: we expect the function to revert with BondNotRedeemable()
    }

    function test_BondInfo() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: Get the bond name
        string memory symbol = iFxb.symbol();

        /// GIVEN: Get the bond symbol
        string memory name = iFxb.name();

        /// GIVEN: Get the bond maturity
        uint256 maturity = iFxb.MATURITY_TIMESTAMP();

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: we get the bond info struct
        FXB.BondInfo memory bondInfo = iFxb.bondInfo();

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ err: "/// THEN: we expect bond info struct symbol to match symbol", a: symbol, b: bondInfo.symbol });
        assertEq({ err: "/// THEN: we expect bond info struct name to match name", a: name, b: bondInfo.name });
        assertEq({
            err: "/// THEN: we expect bond info struct maturity to match maturity",
            a: maturity,
            b: bondInfo.maturityTimestamp
        });
    }

    function test_Mint_ZeroAmount_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: a bond with a maturity of 30 days is created
        (iFxb, ) = _fxbFactory_createFxbContract(block.timestamp + 30 days);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: we try to mint 0 bonds
        startHoax(Constants.Mainnet.FXB_TIMELOCK);
        vm.expectRevert(FXB.ZeroAmount.selector);
        iFxb.mint({ account: address(0x123), value: 0 });

        /// THEN: we expect the function to revert with ZeroAmount()
    }

    function test_Burn_ZeroAmount_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: a bond with a maturity of 30 days is created and expired
        (iFxb, ) = _fxbFactory_createFxbContract(block.timestamp + 30 days);
        vm.warp(block.timestamp + 31 days);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: we try to burn 0 bonds
        startHoax(Constants.Mainnet.FXB_TIMELOCK);
        vm.expectRevert(FXB.ZeroAmount.selector);
        iFxb.burn({ to: address(0x123), value: 0 });

        /// THEN: we expect the function to revert with ZeroAmount()
    }

    function test_UpgradeBeacon_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: a bond exists
        (iFxb, ) = _fxbFactory_createFxbContract(block.timestamp + 30 days);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: we upgrade the bond to a new version
        UpgradedFXB upgradedFxb = new UpgradedFXB();
        FraxBeacon beacon = FraxBeacon(iFxbFactory.beacon());
        vm.prank(beacon.owner());
        beacon.setImplementation(address(upgradedFxb));

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: we expect the bond to be upgraded
        assertTrue(UpgradedFXB(address(iFxb)).foo(), "Bond should be upgraded to UpgradedFXB");
    }
}

contract UpgradedFXB is FXB {
    function foo() external pure returns (bool) {
        return true;
    }
}
