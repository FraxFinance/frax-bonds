// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import "./BaseTest_FXB_LFRAX.t.sol";

contract FXB_LFRAX_Test is BaseTest_FXB_LFRAX {
    using DecimalStringHelper for uint256;

    address bob;
    address alice;
    address fxbTimelock;
    uint256 amount = 2e18;

    // Test users
    address[3] public tstUsers;
    uint256[3] public tstUserPkeys;
    address public allowanceReceiver = 0x5f4E3B89133a578E128eb3b238aa502C675cc210;
    address public permitSpender = 0x36A87d1E3200225f881488E4AEedF25303FebcAe;

    // Before and after comparisons
    address[3] public addressesBefore;
    address[3] public addressesAfter;
    uint256[3] public allowancesBefore;
    uint256[3] public allowancesAfter;
    uint256[3] public noncesBefore;
    uint256[3] public noncesAfter;
    uint256[3] public permitAllowancesBefore;
    uint256[3] public permitAllowancesAfter;
    uint256[3] public balancesBefore;
    uint256[3] public balancesAfter;
    string[3] public stringsBefore;
    string[3] public stringsAfter;
    uint256[3] public versionBefore;
    uint256[3] public versionAfter;
    uint256 public totalSupplyBefore;
    uint256 public totalSupplyAfter;
    uint256 public totalMintedBefore;
    uint256 public totalMintedAfter;
    uint256 public totalRedeemedBefore;
    uint256 public totalRedeemedAfter;
    PermitDetails[3] public prmDetails;

    struct PermitDetails {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 timestamp;
    }

    function setUp() public {
        // Do the core setup
        _setUpNoUpgrade();

        // Do the LFRAX upgrade
        _doLFRAXUpgrade();

        // Do the FXB upgrade
        _doFXBUpgrade();
    }

    function _setUpNoUpgrade() internal {
        /// BACKGROUND: Contracts are deployed
        super.defaultSetup();

        fxbTimelock = fxbFactory.timelockAddress();

        // Initialize FXS and the SigUtils beforehand
        sigUtils_FXB = new SigUtils(fxb2028.DOMAIN_SEPARATOR());

        // Initialize test users
        tstUserPkeys = [0xA11CE, 0xB0B, 0xC4A5E];
        tstUsers = [
            payable(vm.addr(tstUserPkeys[0])),
            payable(vm.addr(tstUserPkeys[1])),
            payable(vm.addr(tstUserPkeys[2]))
        ];

        alice = labelAndDeal(payable(vm.addr(tstUserPkeys[0])), "alice");
        _mintLFraxTo(alice, 1000 ether);

        bob = labelAndDeal(payable(vm.addr(tstUserPkeys[1])), "bob");
        _mintLFraxTo(bob, 1000 ether);

        // Label test users
        vm.label(tstUsers[0], "TU1");
        vm.label(tstUsers[1], "TU2");
        vm.label(tstUsers[2], "TU3");
    }

    function _setTestAllowances() internal {
        // Set test allowances
        for (uint256 i = 0; i < tstUsers.length; i++) {
            // Give users frxUSD
            vm.prank(Constants.FraxtalL2.L2_COMPTROLLER_SAFE);
            frxUSD.transfer(tstUsers[i], 1000e18);

            // Become a test user
            vm.startPrank(tstUsers[i]);

            // Approve frxUSD to FXB for minting
            frxUSD.approve(fxb2028Address, (i + 1) * 100e18);

            // Mint some FXB 1:1 for testing
            fxb2028.mint(tstUsers[i], (i + 1) * 100e18);

            // Set test allowances
            fxb2028.approve(allowanceReceiver, (i + 1) * 100e18);

            vm.stopPrank();
        }
    }

    function test_FXB_LFRAX_InitialState_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================
        uint256 startOf2028 = 1_830_297_600; // 1-1-2028 00:00:00

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ err: "/// THEN: fxb2028.name() incorrect", a: fxb2028.name(), b: "FXB20271231" });
        assertEq({ err: "/// THEN: fxb2028.symbol() incorrect", a: fxb2028.symbol(), b: "FXB20271231" });
        assertEq({
            err: "/// THEN: fxb2028.MATURITY_TIMESTAMP() incorrect",
            a: fxb2028.MATURITY_TIMESTAMP(),
            b: startOf2028
        });

        (uint256 major, uint256 minor, uint256 patch) = fxb2028.version();
        assertEq({ err: "/// THEN: major incorrect", a: major, b: 1 });
        assertEq({ err: "/// THEN: minor incorrect", a: minor, b: 2 }); // 2 indicates the upgrade happened
        assertEq({ err: "/// THEN: patch incorrect", a: patch, b: 0 });
    }

    function test_FXB_LFRAX_IsRedeemable_BeforeMaturity_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: the time is one second before the maturity timestamp
        vm.warp(fxb2028.MATURITY_TIMESTAMP() - 1);
        assertEq({
            err: "/// THEN: block.timestamp should be 1 less than maturity timestamp",
            a: block.timestamp,
            b: fxb2028.MATURITY_TIMESTAMP() - 1
        });

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: bond is not redeemable
        assertFalse(fxb2028.isRedeemable());
    }

    function test_FXB_LFRAX_IsRedeemable_BeforeMaturityAsTimelock_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: the time is one second before the maturity timestamp
        vm.warp(fxb2028.MATURITY_TIMESTAMP() - 1);
        assertEq({
            err: "/// THEN: block.timestamp should be 1 less than maturity timestamp",
            a: block.timestamp,
            b: fxb2028.MATURITY_TIMESTAMP() - 1
        });

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: bond is redeemable
        vm.startPrank(fxbTimelock);
        assertTrue(fxb2028.isRedeemable());
    }

    function test_FXB_LFRAX_IsRedeemable_AtMaturity_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: the time is at the maturity timestamp
        vm.warp(fxb2028.MATURITY_TIMESTAMP());
        assertEq({
            err: "/// THEN: block.timestamp should equal maturity timestamp",
            a: block.timestamp,
            b: fxb2028.MATURITY_TIMESTAMP()
        });

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: bond is redeemable
        assertTrue(fxb2028.isRedeemable());
    }

    function test_FXB_LFRAX_TimelockIsRedeemable_AtMaturityAsTimelock_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: the time is at the maturity timestamp
        vm.warp(fxb2028.MATURITY_TIMESTAMP());
        assertEq({
            err: "/// THEN: block.timestamp should equal maturity timestamp",
            a: block.timestamp,
            b: fxb2028.MATURITY_TIMESTAMP()
        });

        //==============================================================================
        // Assert
        //==============================================================================

        /// THEN: bond is redeemable
        vm.startPrank(fxbTimelock);
        assertTrue(fxb2028.isRedeemable());
    }

    function test_FXB_LFRAX_Mint_NotApproved_reverts() public {
        /// GIVEN: a user has not approved FRAX
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: a user tries to mint a bond
        hoax(Constants.Mainnet.OPERATOR_ADDRESS);
        vm.expectRevert();
        fxb2028.mint(bob, 1e18);

        /// THEN: we expect the function to revert with ERC20: transfer amount exceeds allowance
    }

    function test_FXB_LFRAX_Mint_BeforeMaturity_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================
        // GIVEN: a user has approved FRAX
        hoax(bob);
        lFrax.approve(fxb2028Address, amount);

        FxbStorageSnapshot memory initial_fxbSnapshot = fxbStorageSnapshot(fxb2028);
        AccountStorageSnapshot memory initial_bobAccountSnapshot = accountStorageSnapshot(
            bob,
            IERC20(address(lFrax)),
            fxb2028
        );
        AccountStorageSnapshot memory initial_aliceAccountSnapshot = accountStorageSnapshot(
            alice,
            IERC20(address(lFrax)),
            fxb2028
        );

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: a user tries mints bonds with amount FRAX to another user as the recipient
        hoax(bob);
        fxb2028.mint(alice, amount);

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
            a: delta_fxbSnapshot.delta.lFraxSnapshot.balanceOf,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the totalSupply of fxb to increase by amount",
            a: delta_fxbSnapshot.delta.totalSupply,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the frax balance of sender to decrease by amount",
            a: delta_bobAccountSnapshot.delta.lFraxSnapshot.balanceOf,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the fxb balance of recipient to increase by amount",
            a: delta_aliceAccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: amount
        });
    }

    function test_FXB_LFRAX_Mint_AfterMaturity_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: 3 years have passed (and we are passed maturity)
        mineBlocksBySecond(3 * 12 * (30 days));
        assertTrue(fxb2028.isRedeemable(), "Should be redeemable now");

        // GIVEN: a user has approved FRAX
        hoax(bob);
        lFrax.approve(fxb2028Address, amount);
        console.log("part1");

        FxbStorageSnapshot memory initial_fxbSnapshot = fxbStorageSnapshot(fxb2028);
        AccountStorageSnapshot memory initial_bobAccountSnapshot = accountStorageSnapshot(
            bob,
            IERC20(address(lFrax)),
            fxb2028
        );
        AccountStorageSnapshot memory initial_aliceAccountSnapshot = accountStorageSnapshot(
            alice,
            IERC20(address(lFrax)),
            fxb2028
        );

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: a user tries mints bonds with 1e18 FRAX to another user as the recipient
        hoax(bob);
        console.log("part1.5");
        fxb2028.mint(alice, amount);
        console.log("part2");

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
            a: delta_fxbSnapshot.delta.lFraxSnapshot.balanceOf,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the totalSupply of fxb to increase by amount",
            a: delta_fxbSnapshot.delta.totalSupply,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the frax balance of sender to decrease by amount",
            a: delta_bobAccountSnapshot.delta.lFraxSnapshot.balanceOf,
            b: amount
        });

        assertEq({
            err: "/// THEN: we expect the fxb balance of recipient to increase by amount",
            a: delta_aliceAccountSnapshot.delta.fxbSnapshot.balanceOf,
            b: amount
        });
    }

    function test_FXB_LFRAX_Burn_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        // Give the operator some lFRAX
        _mintLFraxTo(Constants.Mainnet.OPERATOR_ADDRESS, amount);

        /// GIVEN: Approve FRAX to the bond contract (as the operator)
        hoax(Constants.Mainnet.OPERATOR_ADDRESS);
        lFrax.approve(fxb2028Address, amount);

        /// GIVEN: Operator has minted the bond to the tester
        hoax(Constants.Mainnet.OPERATOR_ADDRESS);
        fxb2028.mint(tester, amount);

        /// GIVEN: 3 years have passed (and we are passed maturity)
        mineBlocksBySecond(3 * 12 * (30 days));

        // GIVEN: isBondRedeemable returns true
        assertEq(fxb2028.isRedeemable(), true, "Make sure the bond is redeemable");

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: the user tries to redeem their full balance
        vm.startPrank(tester);
        uint256 balanceBefore = lFrax.balanceOf(tester);
        fxb2028.burn(tester, amount);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ err: "/// THEN: we expect the user to have 0 bond", a: fxb2028.balanceOf(tester), b: 0 });
        assertEq({
            err: "/// THEN: we expect the user to have gained amount",
            a: lFrax.balanceOf(tester) - balanceBefore,
            b: amount
        });
    }

    function test_FXB_LFRAX_Burn_BeforeMaturityAsTimelock_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        // Give the timelock some lFRAX
        _mintLFraxTo(fxbTimelock, amount);

        /// GIVEN: Approve FRAX to the bond contract (as the timelock)
        vm.startPrank(fxbTimelock);
        lFrax.approve(fxb2028Address, amount);

        /// GIVEN: Operator has minted the bond to the timelock
        fxb2028.mint(fxbTimelock, amount);
        vm.stopPrank();

        test_FXB_LFRAX_IsRedeemable_BeforeMaturityAsTimelock_succeeds();

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: the fxbTimelock tries to redeem their full balance
        vm.startPrank(fxbTimelock);
        uint256 balanceBefore = lFrax.balanceOf(fxbTimelock);
        fxb2028.burn(fxbTimelock, amount);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            err: "/// THEN: we expect the fxbTimelock to have 0 bond",
            a: fxb2028.balanceOf(fxbTimelock),
            b: 0
        });
        assertEq({
            err: "/// THEN: we expect the fxbTimelock to have gained amount",
            a: lFrax.balanceOf(fxbTimelock) - balanceBefore,
            b: amount
        });
    }

    function test_FXB_LFRAX_Burn_BondNotRedeemable_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        // Give the timelock some lFRAX
        _mintLFraxTo(fxbTimelock, amount);

        /// GIVEN: Approve FRAX to the bond contract (as the operator)
        hoax(fxbTimelock);
        lFrax.approve(fxb2028Address, amount);

        /// GIVEN: Operator has minted the bond to the tester
        hoax(fxbTimelock);
        fxb2028.mint(tester, amount);

        //==============================================================================
        // Act
        //==============================================================================

        /// GIVEN: the maturity date has not passed
        // WHEN: the user tries to redeem
        vm.startPrank(tester);
        vm.expectRevert(FXB.BondNotRedeemable.selector);
        fxb2028.burn(tester, amount);

        /// THEN: we expect the function to revert with BondNotRedeemable()
    }

    function test_FXB_LFRAX_BondInfo() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: Get the bond name
        string memory symbol = fxb2028.symbol();

        /// GIVEN: Get the bond symbol
        string memory name = fxb2028.name();

        /// GIVEN: Get the bond maturity
        uint256 maturity = fxb2028.MATURITY_TIMESTAMP();

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: we get the bond info struct
        FXB.BondInfo memory bondInfo = fxb2028.bondInfo();

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

    function test_FXB_LFRAX_Mint_ZeroAmount_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: we try to mint 0 bonds
        startHoax(Constants.Mainnet.FXB_TIMELOCK);
        vm.expectRevert(FXB.ZeroAmount.selector);
        fxb2028.mint({ account: address(0x123), value: 0 });

        /// THEN: we expect the function to revert with ZeroAmount()
    }

    function test_FXB_LFRAX_Burn_ZeroAmount_reverts() public {
        //==============================================================================
        // Act
        //==============================================================================

        /// GIVEN: 3 years have passed (and we are passed maturity)
        mineBlocksBySecond(3 * 12 * (30 days));

        /// WHEN: we try to burn 0 bonds
        startHoax(Constants.Mainnet.FXB_TIMELOCK);
        vm.expectRevert(FXB.ZeroAmount.selector);
        fxb2028.burn({ to: address(0x123), value: 0 });

        /// THEN: we expect the function to revert with ZeroAmount()
    }

    function test_FXB_LFRAX_Upgrading() public {
        _setUpNoUpgrade();
        _setTestAllowances();

        // Snapshot the state beforehand
        // https://book.getfoundry.sh/cheatcodes/state-snapshots
        // uint256 snapshotBefore = vm.snapshotState();
        // See also: https://book.getfoundry.sh/cheatcodes/start-state-diff-recording

        // Check the state before and after
        console.log(unicode"★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★");
        console.log(unicode"★★★★★★★★★★★★★★★★★★★★★★★★★ STATE TESTS ★★★★★★★★★★★★★★★★★★★★★★★★★");
        console.log(unicode"★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★");

        // ================================================
        // Note the state before (jank method)
        // ================================================
        console.log("============= STATE BEFORE =============");

        // Strings
        stringsBefore[0] = fxb2028.name();
        stringsBefore[1] = fxb2028.symbol();
        (versionBefore[0], versionBefore[1], versionBefore[2]) = fxb2028.version();
        console.log("name: ", stringsBefore[0]);
        console.log("symbol: ", stringsBefore[1]);
        console.log("version [0]: ", versionBefore[0]);
        console.log("version [1]: ", versionBefore[1]);
        console.log("version [2]: ", versionBefore[2]);

        // Total Supply
        totalSupplyBefore = fxb2028.totalSupply();
        console.log("totalSupply: ", totalSupplyBefore);

        // Total Minted
        totalMintedBefore = fxb2028.totalFxbMinted();
        console.log("totalFxbMinted: ", totalMintedBefore);

        // Total Redeemed
        totalRedeemedBefore = fxb2028.totalFxbRedeemed();
        console.log("totalFxbRedeemed: ", totalRedeemedBefore);

        // Note balances, allowances, and nonces before
        for (uint256 i = 0; i < tstUsers.length; i++) {
            console.log("-------- %s --------", vm.getLabel(tstUsers[i]));
            balancesBefore[i] = fxb2028.balanceOf(tstUsers[i]);
            allowancesBefore[i] = fxb2028.allowance(tstUsers[i], allowanceReceiver);
            noncesBefore[i] = fxb2028.nonces(tstUsers[i]);

            console.log("Balance (dec'd): ", balancesBefore[i].decimalString(18, false));
            console.log("Allowance [normal] (dec'd): ", allowancesBefore[i].decimalString(18, false));
            console.log("Nonces: ", noncesBefore[i]);
        }

        // Upgrade
        _doFXBUpgrade();

        // Deploy new sigUtils
        sigUtils_FXB_LFRAX = new SigUtils(fxb2028.DOMAIN_SEPARATOR());

        // ================================================
        // Note the state after (jank method)
        // ================================================
        console.log("============= STATE AFTER =============");

        // Strings
        stringsAfter[0] = fxb2028.name();
        stringsAfter[1] = fxb2028.symbol();
        (versionAfter[0], versionAfter[1], versionAfter[2]) = fxb2028.version();
        console.log("name: ", stringsAfter[0]);
        console.log("symbol: ", stringsAfter[1]);
        console.log("version [0]: ", versionAfter[0]);
        console.log("version [1]: ", versionAfter[1]);
        console.log("version [2]: ", versionAfter[2]);

        // Total Supply
        totalSupplyAfter = fxb2028.totalSupply();
        console.log("totalSupply: ", totalSupplyAfter);
        assertEq(totalSupplyBefore, totalSupplyAfter, "totalSupply mismatch");

        // Total Minted
        totalMintedAfter = fxb2028.totalFxbMinted();
        console.log("totalFxbMinted: ", totalMintedAfter);
        assertEq(totalMintedBefore, totalMintedAfter, "totalFxbMinted mismatch");

        // Total Redeemed
        totalRedeemedAfter = fxb2028.totalFxbRedeemed();
        console.log("totalFxbRedeemed: ", totalRedeemedAfter);
        assertEq(totalRedeemedBefore, totalRedeemedAfter, "totalFxbRedeemed mismatch");

        // Note balances and allowances after
        for (uint256 i = 0; i < tstUsers.length; i++) {
            console.log("----- %s -----", vm.getLabel(tstUsers[i]));
            balancesAfter[i] = fxb2028.balanceOf(tstUsers[i]);
            allowancesAfter[i] = fxb2028.allowance(tstUsers[i], allowanceReceiver);
            noncesAfter[i] = fxb2028.nonces(tstUsers[i]);

            console.log("Balance (dec'd): ", balancesAfter[i].decimalString(18, false));
            console.log("Allowance [normal] (dec'd): ", allowancesAfter[i].decimalString(18, false));
            console.log("Nonces: ", noncesAfter[i]);

            // Assert that they did not change
            assertEq(balancesBefore[i], balancesAfter[i], "Balance mismatch");
            assertEq(allowancesBefore[i], allowancesAfter[i], "Allowance mismatch");

            // Check permit allowance beforehand
            permitAllowancesBefore[i] = fxb2028.allowance(tstUsers[i], permitSpender);
            console.log("Allowance [permit, before] (dec'd): ", permitAllowancesBefore[i].decimalString(18, false));
            assertEq(permitAllowancesBefore[i], 0, "Permit allowance should be 0 beforehand");

            // Sign a test permit
            uint256 timestampToUse = block.timestamp + (1 days);
            uint256 permitNonce = fxb2028.nonces(tstUsers[i]);
            SigUtils.Permit memory permit = SigUtils.Permit({
                owner: tstUsers[i],
                spender: permitSpender,
                value: 10e18,
                nonce: permitNonce,
                deadline: timestampToUse
            });
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(tstUserPkeys[i], sigUtils_FXB_LFRAX.getTypedDataHash(permit));

            console.log("Signed the permit");
            prmDetails[i] = PermitDetails(v, r, s, timestampToUse);
            // console.log("---v---");
            // console.log(v);
            // console.log("---r---");
            // console.logBytes32(r);
            // console.log("---s---");
            // console.logBytes32(s);
            // console.log("---timestampToUse---");
            // console.log(timestampToUse);

            // Use the permit
            vm.prank(permitSpender);
            fxb2028.permit(
                tstUsers[i],
                permitSpender,
                10e18,
                prmDetails[i].timestamp,
                prmDetails[i].v,
                prmDetails[i].r,
                prmDetails[i].s
            );

            // Check permit allowance and nonce after
            permitAllowancesAfter[i] = fxb2028.allowance(tstUsers[i], permitSpender);
            console.log("Allowance [permit, after] (dec'd): ", permitAllowancesAfter[i].decimalString(18, false));
            assertEq(permitAllowancesAfter[i], 10e18, "Permit allowance should be 10 afterwards");
            assertEq(fxb2028.nonces(tstUsers[i]), permitNonce + 1, "Permit nonce should have increased");
        }

        // Function testing
        // mint, burn, etc and some other functions should not work now...
        console.log(unicode"★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★");
        console.log(unicode"★★★★★★★★★★★★★★★★★★★★★★★ FUNCTION TESTS ★★★★★★★★★★★★★★★★★★★★★★★★");
        console.log(unicode"★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★");

        // Transfer
        console.log("============= TRANSFER =============");
        for (uint256 i = 0; i < tstUsers.length; i++) {
            // Try to transfer too much (should fail)
            vm.prank(tstUsers[i]);
            vm.expectRevert();
            fxb2028.transfer(allowanceReceiver, 100_000e18);

            // Try to transferFrom without an allowance
            vm.prank(tstUsers[i]);
            vm.expectRevert();
            fxb2028.transferFrom(allowanceReceiver, tstUsers[i], 100_000e18);

            // Approve to the allowanceReceiver
            vm.prank(tstUsers[i]);
            fxb2028.approve(allowanceReceiver, 1e18);

            // allowanceReceiver should be able to transferFrom, both to himself and to elsewhere.
            vm.prank(allowanceReceiver);
            fxb2028.transferFrom(tstUsers[i], allowanceReceiver, 0.5e18);
            vm.prank(allowanceReceiver);
            fxb2028.transferFrom(tstUsers[i], permitSpender, 0.5e18);

            // Cannot spend more than allowed
            vm.prank(allowanceReceiver);
            vm.expectRevert();
            fxb2028.transferFrom(tstUsers[i], permitSpender, 0.5e18);
        }
    }
}
