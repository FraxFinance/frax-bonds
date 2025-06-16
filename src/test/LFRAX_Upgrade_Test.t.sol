// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import "./BaseTest_FXB_LFRAX.t.sol";

contract LFRAX_Upgrade_Test is BaseTest_FXB_LFRAX {
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

        // Do the upgrade
        _doLFRAXUpgrade();
    }

    function _setUpNoUpgrade() internal {
        /// BACKGROUND: Contracts are deployed
        super.defaultSetup();

        // Initialize test users
        tstUserPkeys = [0xA11CE, 0xB0B, 0xC4A5E];
        tstUsers = [
            payable(vm.addr(tstUserPkeys[0])),
            payable(vm.addr(tstUserPkeys[1])),
            payable(vm.addr(tstUserPkeys[2]))
        ];

        // Label test users
        vm.label(tstUsers[0], "TU1");
        vm.label(tstUsers[1], "TU2");
        vm.label(tstUsers[2], "TU3");
    }

    function _setTestAllowances() internal {
        // Set test allowances
        for (uint256 i = 0; i < tstUsers.length; i++) {
            // Give users frxUSD
            // vm.prank(Constants.FraxtalL2.L2_COMPTROLLER_SAFE);
            vm.prank(0x96A394058E2b84A89bac9667B19661Ed003cF5D4);
            frxUSD.transfer(tstUsers[i], 1000e18);

            // Become a test user
            vm.startPrank(tstUsers[i]);

            vm.stopPrank();
        }
    }

    function test_LFRAX_Upgrading() public {
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

        // // Strings
        // stringsBefore[0] = lFrax.name();
        // stringsBefore[1] = lFrax.symbol();
        // console.log("name: ", stringsBefore[0]);
        // console.log("symbol: ", stringsBefore[1]);

        // // Note balances and allowances before
        // for (uint256 i = 0; i < tstUsers.length; i++) {
        //     console.log("-------- %s --------", vm.getLabel(tstUsers[i]));
        //     balancesBefore[i] = lFrax.balanceOf(tstUsers[i]);
        //     allowancesBefore[i] = lFrax.allowance(tstUsers[i], allowanceReceiver);
        //     noncesBefore[i] = lFrax.nonces(tstUsers[i]);

        //     console.log("Balance (dec'd): ", balancesBefore[i].decimalString(18, false));
        //     console.log("Allowance [normal] (dec'd): ", allowancesBefore[i].decimalString(18, false));
        //     console.log("Nonces: ", noncesBefore[i]);
        // }

        // Upgrade
        _doLFRAXUpgrade();

        // Deploy new sigUtils
        sigUtils_LFRAX = new SigUtils(lFrax.DOMAIN_SEPARATOR());

        // ================================================
        // Note the state after (jank method)
        // ================================================
        console.log("============= STATE AFTER =============");

        // Strings
        stringsAfter[0] = lFrax.name();
        stringsAfter[1] = lFrax.symbol();
        console.log("name: ", stringsAfter[0]);
        console.log("symbol: ", stringsAfter[1]);

        // Note balances and allowances after
        for (uint256 i = 0; i < tstUsers.length; i++) {
            console.log("----- %s -----", vm.getLabel(tstUsers[i]));
            balancesAfter[i] = lFrax.balanceOf(tstUsers[i]);
            allowancesAfter[i] = lFrax.allowance(tstUsers[i], allowanceReceiver);
            noncesAfter[i] = lFrax.nonces(tstUsers[i]);
            console.log("Balance (dec'd): ", balancesAfter[i].decimalString(18, false));
            console.log("Allowance [normal] (dec'd): ", allowancesAfter[i].decimalString(18, false));
            console.log("Nonces: ", noncesBefore[i]);

            // // Assert that they did not change
            // assertEq(balancesBefore[i], balancesAfter[i], "Balance mismatch");
            // assertEq(allowancesBefore[i], allowancesAfter[i], "Allowance mismatch");
            // assertEq(noncesBefore[i], noncesAfter[i], "Nonces mismatch");

            // Sign a test permit
            uint256 timestampToUse = block.timestamp + (1 days);
            uint256 permitNonce = lFrax.nonces(tstUsers[i]);
            SigUtils.Permit memory permit = SigUtils.Permit({
                owner: tstUsers[i],
                spender: permitSpender,
                value: 10e18,
                nonce: permitNonce,
                deadline: timestampToUse
            });
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(tstUserPkeys[i], sigUtils_LFRAX.getTypedDataHash(permit));

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
            lFrax.permit(
                tstUsers[i],
                permitSpender,
                10e18,
                prmDetails[i].timestamp,
                prmDetails[i].v,
                prmDetails[i].r,
                prmDetails[i].s
            );

            // Check permit allowance and nonce after
            permitAllowancesAfter[i] = lFrax.allowance(tstUsers[i], permitSpender);
            console.log("Allowance [permit, after] (dec'd): ", permitAllowancesAfter[i].decimalString(18, false));
            assertEq(permitAllowancesAfter[i], 10e18, "Permit allowance should be 10 afterwards");
            assertEq(lFrax.nonces(tstUsers[i]), permitNonce + 1, "Permit nonce should have increased");
        }

        // Function testing
        // mint, burn, etc and some other functions should not work now...
        console.log(unicode"★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★");
        console.log(unicode"★★★★★★★★★★★★★★★★★★★★★★★ FUNCTION TESTS ★★★★★★★★★★★★★★★★★★★★★★★★");
        console.log(unicode"★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★");

        // Transfer
        console.log("============= TRANSFER =============");
        for (uint256 i = 0; i < tstUsers.length; i++) {
            console.log("----- %s -----", vm.getLabel(tstUsers[i]));

            // Try to transfer too much (should fail)
            console.log(" -- Transfer too much");
            vm.prank(tstUsers[i]);
            vm.expectRevert();
            lFrax.transfer(allowanceReceiver, 100_000e18);

            // Try to transferFrom without an allowance
            console.log(" -- transferFrom without an allowance");
            vm.prank(tstUsers[i]);
            vm.expectRevert();
            lFrax.transferFrom(allowanceReceiver, tstUsers[i], 100_000e18);

            // Approve to the allowanceReceiver
            console.log(" -- Approve to the allowanceReceiver");
            vm.prank(tstUsers[i]);
            lFrax.approve(allowanceReceiver, 1e18);

            // allowanceReceiver should be able to transferFrom, both to himself and to elsewhere.
            console.log(" -- allowanceReceiver should be able to transferFrom, both to himself and to elsewhere");
            vm.prank(allowanceReceiver);
            lFrax.transferFrom(tstUsers[i], allowanceReceiver, 0.5e18);
            vm.prank(allowanceReceiver);
            lFrax.transferFrom(tstUsers[i], permitSpender, 0.5e18);

            // Cannot spend more than allowed
            console.log(" -- Cannot spend more than allowed");
            vm.prank(allowanceReceiver);
            vm.expectRevert();
            lFrax.transferFrom(tstUsers[i], permitSpender, 0.5e18);
        }
    }
}
