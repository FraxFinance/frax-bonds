// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/script/LFRAX_FXB_Upgrade/LFRAXUpgradeSharedState.sol";

contract HandleNewLFRAX is LFRAXUpgradeSharedState {
    string txBatchJson =
        '{"version":"1.0","chainId":"252","createdAt":66666666666666,"meta":{"name":"01_HandleNewLFRAX","description":"","txBuilderVersion":"1.18.0","createdFromSafeAddress":"<SIGNING_SAFE_ADDRESS>","createdFromOwnerAddress":"","checksum":"<CHECKSUM>"},"transactions":[{},{}]}';
    string JSON_PATH = "src/script/LFRAX_FXB_Upgrade/JSONs/01_HandleNewLFRAX.json";

    function setupState() internal virtual {
        super.defaultSetup();

        // Create the json
        vm.writeJson(txBatchJson, JSON_PATH);

        // Set misc json variables
        vm.writeJson(Strings.toString(uint256(1)), JSON_PATH, ".chainId");
        vm.writeJson(Strings.toString(uint256(block.timestamp)), JSON_PATH, ".createdAt");
        vm.writeJson(Strings.toHexString(address(pxyAdminLFraxOwner)), JSON_PATH, ".meta.createdFromSafeAddress");
    }

    function run() public virtual {
        // Set up the state
        setupState();

        // Start broadcasting
        vm.startBroadcast(deployerPrivateKey);
        console.log("Executing as", deployerAddr);

        // StorageSet the Legacy Frax Dollar (LFRAX) proxy
        // =======================================================
        // Get the calldata
        _theCalldata = abi.encodeWithSelector(
            IProxyAdmin.upgradeAndCall.selector,
            payable(lFraxAddress),
            address(storageSetterLFRAX),
            abi.encodeWithSignature("setNameAndSymbol()")
        );

        // Fill the tx json and write
        _txJson = generateTxJson(address(pxyAdminLFrax), _theCalldata);
        vm.writeJson(_txJson, JSON_PATH, ".transactions[0]");

        // StorageSet the Legacy Frax Dollar (LFRAX) proxy
        // =======================================================

        // Get the calldata
        _theCalldata = abi.encodeWithSelector(IProxyAdmin.upgrade.selector, lFraxAddress, address(lFraxImpl));

        // Fill the tx json and write
        _txJson = generateTxJson(address(pxyAdminLFrax), _theCalldata);
        vm.writeJson(_txJson, JSON_PATH, ".transactions[1]");

        vm.stopBroadcast();
    }
}
