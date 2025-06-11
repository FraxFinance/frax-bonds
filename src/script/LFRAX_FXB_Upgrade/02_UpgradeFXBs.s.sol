// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "src/script/LFRAX_FXB_Upgrade/LFRAXUpgradeSharedState.sol";

contract UpgradeFXBs is LFRAXUpgradeSharedState {
    string txBatchJson =
        '{"version":"1.0","chainId":"252","createdAt":66666666666666,"meta":{"name":"02_UpgradeFXBs","description":"","txBuilderVersion":"1.18.0","createdFromSafeAddress":"<SIGNING_SAFE_ADDRESS>","createdFromOwnerAddress":"","checksum":"<CHECKSUM>"},"transactions":[{},{},{},{},{},{},{},{},{},{},{}]}';
    string JSON_PATH = "src/script/LFRAX_FXB_Upgrade/JSONs/02_UpgradeFXBs.json";

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

        // Upgrade FXB20251231
        // =======================================================
        // Encode the initialization call
        _theEncodedCall = abi.encodeCall(
            lFRAXFXBImpl.initialize,
            (FXB20251231.name(), lFraxAddress, address(frxUSD), FXB20251231.MATURITY_TIMESTAMP(), FXB20251231.factory())
        );

        // Get the calldata
        _theCalldata = abi.encodeWithSelector(
            IProxyAdmin.upgradeAndCall.selector,
            address(FXB20251231),
            address(lFRAXFXBImpl),
            _theEncodedCall
        );

        // Fill the tx json and write
        _txJson = generateTxJson(address(pxyAdminFXB), _theCalldata);
        vm.writeJson(_txJson, JSON_PATH, ".transactions[0]");

        // Upgrade FXB20271231
        // =======================================================
        // Encode the initialization call
        _theEncodedCall = abi.encodeCall(
            lFRAXFXBImpl.initialize,
            (FXB20271231.name(), lFraxAddress, address(frxUSD), FXB20271231.MATURITY_TIMESTAMP(), FXB20271231.factory())
        );

        // Get the calldata
        _theCalldata = abi.encodeWithSelector(
            IProxyAdmin.upgradeAndCall.selector,
            address(FXB20271231),
            address(lFRAXFXBImpl),
            _theEncodedCall
        );

        // Fill the tx json and write
        _txJson = generateTxJson(address(pxyAdminFXB), _theCalldata);
        vm.writeJson(_txJson, JSON_PATH, ".transactions[1]");

        // Upgrade FXB20291231
        // =======================================================
        // Encode the initialization call
        _theEncodedCall = abi.encodeCall(
            lFRAXFXBImpl.initialize,
            (FXB20291231.name(), lFraxAddress, address(frxUSD), FXB20291231.MATURITY_TIMESTAMP(), FXB20291231.factory())
        );

        // Get the calldata
        _theCalldata = abi.encodeWithSelector(
            IProxyAdmin.upgradeAndCall.selector,
            address(FXB20291231),
            address(lFRAXFXBImpl),
            _theEncodedCall
        );

        // Fill the tx json and write
        _txJson = generateTxJson(address(pxyAdminFXB), _theCalldata);
        vm.writeJson(_txJson, JSON_PATH, ".transactions[2]");

        // Upgrade FXB20551231
        // =======================================================
        // Encode the initialization call
        _theEncodedCall = abi.encodeCall(
            lFRAXFXBImpl.initialize,
            (FXB20551231.name(), lFraxAddress, address(frxUSD), FXB20551231.MATURITY_TIMESTAMP(), FXB20551231.factory())
        );

        // Get the calldata
        _theCalldata = abi.encodeWithSelector(
            IProxyAdmin.upgradeAndCall.selector,
            address(FXB20551231),
            address(lFRAXFXBImpl),
            _theEncodedCall
        );

        // Fill the tx json and write
        _txJson = generateTxJson(address(pxyAdminFXB), _theCalldata);
        vm.writeJson(_txJson, JSON_PATH, ".transactions[3]");

        vm.stopBroadcast();
    }
}
