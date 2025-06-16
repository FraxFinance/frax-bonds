// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/script/LFRAX_FXB_Upgrade/LFRAXUpgradeSharedState.sol";

contract DeployImpls is LFRAXUpgradeSharedState {
    function setupState() internal virtual {
        super.defaultSetup();
    }

    function run() public virtual {
        // Set up the state
        setupState();

        // Start broadcasting
        vm.startBroadcast(deployerPrivateKey);
        console.log("Executing as", deployerAddr);

        // Deploy StorageSetterLFRAX
        // =======================================================
        storageSetterLFRAX = new StorageSetterLFRAX();

        // // Deploy LFRAX impl
        // USE THE FACTORY!!!
        // // =======================================================
        // lFraxImpl = new ERC20PermitPermissionedOptiMintable(
        //     address(pxyAdminLFraxOwner),
        //     Constants.Mainnet.FXB_TIMELOCK,
        //     0x4200000000000000000000000000000000000010, // L2StandardBridge
        //     0x853d955aCEf822Db058eb8505911ED77F175b99e, // Legacy Frax Dollar
        //     "Legacy Frax Dollar",
        //     "LFRAX"
        // );

        // Deploy LFRAX_FXB impl
        // =======================================================
        lFRAXFXBImpl = new FXB_LFRAX();

        console.log("===================== IMPL ADDRESSES (UPDATE LFRAXUpgradeSharedState NOW) =====================");
        console.log("address internal constant STORAGE_SETTER_LFRAX = %s;", address(storageSetterLFRAX));
        console.log("address internal constant LFRAX_IMPL = %s;", address(lFraxImpl));
        console.log("address internal constant LFRAXFXB_IMPL = %s;", address(lFRAXFXBImpl));

        vm.stopBroadcast();
    }
}
