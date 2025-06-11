// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import "frax-std/FraxTest.sol";
import { DecimalStringHelper } from "src/test/helpers/DecimalStringHelper.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FXB } from "src/contracts/FXB.sol";
import { FXBFactory } from "src/contracts/FXBFactory.sol";
import { FXB_LFRAX } from "src/contracts/FXB_LFRAX.sol";
import { ERC20PermitPermissionedOptiMintable } from "src/contracts/ERC20PermitPermissionedOptiMintable.sol";
import { IGnosisSafe } from "src/contracts/interfaces/IGnosisSafe.sol";
import { IProxyAdmin } from "src/contracts/interfaces/IProxyAdmin.sol";
import { SlippageAuction } from "src/contracts/SlippageAuction.sol";
import { SlippageAuctionFactory } from "src/contracts/SlippageAuctionFactory.sol";
import { StorageSetterLFRAX } from "src/contracts/utils/StorageSetterLFRAX.sol";
import { TransparentUpgradeableProxy, ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { console } from "frax-std/FraxTest.sol";
import "src/Constants.sol" as Constants;

contract LFRAXUpgradeSharedState is BaseScript {
    // Non-FXB ERC20s
    address public lFraxAddress = 0xff000000000000000000000000000000000001Fd;
    ERC20PermitPermissionedOptiMintable public lFraxImpl =
        ERC20PermitPermissionedOptiMintable(Constants.FraxtalL2.LFRAX_IMPL);
    ITransparentUpgradeableProxy public lFraxPxy = ITransparentUpgradeableProxy(lFraxAddress);
    ERC20PermitPermissionedOptiMintable public lFrax = ERC20PermitPermissionedOptiMintable(lFraxAddress);
    ERC20 public frxUSD = ERC20(0xFc00000000000000000000000000000000000001);

    // StorageSetterLFRAX
    StorageSetterLFRAX public storageSetterLFRAX = StorageSetterLFRAX(Constants.FraxtalL2.STORAGE_SETTER_LFRAX);

    // FXB related
    FXBFactory public fxbFactory = FXBFactory(0xaFa1705021f65418e746D8664f4B8A58271f6De4);
    FXB_LFRAX public lFRAXFXBImpl = FXB_LFRAX(Constants.FraxtalL2.LFRAXFXB_IMPL);
    FXB public FXB20251231 = FXB(0xacA9A33698cF96413A40A4eB9E87906ff40fC6CA);
    FXB public FXB20271231 = FXB(0x6c9f4E6089c8890AfEE2bcBA364C2712f88fA818);
    FXB public FXB20291231 = FXB(0xF1e2b576aF4C6a7eE966b14C810b772391e92153);
    FXB public FXB20551231 = FXB(0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83);

    // Safes
    IGnosisSafe public l2Safe;
    address public l2SafeAddress;

    // ProxyAdmins
    IProxyAdmin pxyAdminLFrax;
    address pxyAdminLFraxOwner;
    IProxyAdmin pxyAdminFXB;
    address pxyAdminFXBOwner;

    // To prevent stack-too-deep
    // ------------------------------
    string _txJson;
    bytes _theCalldata;
    bytes _theEncodedCall;

    // Misc others
    uint256 public _safeThreshold;
    address[] public _safeOwners;
    bytes32 public _safeTxHash;

    // Check https://github.com/ethereum-optimism/optimism/blob/6a871c54512ebdb749f46ccb7d27b1b60510eba1/op-deployer/pkg/deployer/init.go#L112 for logic
    // For tests
    uint256 public deployerPrivateKey;
    address public deployerAddr;

    function defaultSetup() internal virtual {
        // Find the proxy admin for LFRAX
        // Should be 0xfc00000000000000000000000000000000000009 (ProxyAdmin (RSVD10K_FC0AFC65_FF01FF2711))
        bytes32 adminSlot = vm.load(lFraxAddress, ERC1967Utils.ADMIN_SLOT);
        pxyAdminLFrax = IProxyAdmin(address(uint160(uint256(adminSlot))));
        vm.label(address(pxyAdminLFrax), "pxyAdminLFrax");
        console.log("Proxy Admin (LFRAX): ", address(pxyAdminLFrax));
        pxyAdminLFraxOwner = pxyAdminLFrax.owner();
        vm.label(address(pxyAdminLFraxOwner), "pxyAdminLFraxOwner");
        console.log("Proxy Admin Owner (LFRAX): ", address(pxyAdminLFraxOwner));

        // Find the proxy admin for the FXBs
        // Should be ????
        adminSlot = vm.load(address(FXB20251231), ERC1967Utils.ADMIN_SLOT);
        pxyAdminFXB = IProxyAdmin(address(uint160(uint256(adminSlot))));
        vm.label(address(pxyAdminFXB), "pxyAdminFXB");
        console.log("Proxy Admin (FXBs): ", address(pxyAdminFXB));
        pxyAdminFXBOwner = pxyAdminFXB.owner();
        vm.label(address(pxyAdminFXBOwner), "pxyAdminFXBOwner");
        console.log("Proxy Admin Owner (FXBs): ", address(pxyAdminFXBOwner));

        // Set up deployer
        deployerPrivateKey = vm.envUint("PK");
        deployerAddr = vm.addr(deployerPrivateKey);
    }

    function generateTxJson(address _to, bytes memory _data) public returns (string memory _txString) {
        _txString = "{";
        _txString = string.concat(_txString, '"to": "', Strings.toHexString(_to), '", ');
        _txString = string.concat(_txString, '"value": "0", ');
        _txString = string.concat(_txString, '"data": "', iToHex(_data, true), '", ');
        _txString = string.concat(_txString, '"contractMethod": null, ');
        _txString = string.concat(_txString, '"contractInputsValues": null');
        _txString = string.concat(_txString, "}");
    }

    function iToHex(bytes memory buffer, bool _addPrefix) public pure returns (string memory) {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        if (_addPrefix) return string(abi.encodePacked("0x", converted));
        else return string(abi.encodePacked(converted));
    }

    // function execSafeTx_L1_00(address _to, bytes memory _calldata, bool _approveToo) public {
    //     _execL1SafeTx(_to, _calldata, _approveToo);
    // }

    // function execSafeTx_L1_01(address _to, bytes memory _calldata, bool _approveToo, address _proxyAddress) public {
    //     // Skip if StorageSetterRestricted is already there and initialization was cleared
    //     try StorageSetterRestricted(_proxyAddress).getUint(0) returns (uint256 _result) {
    //         console.log("   -- _result: ", _result);
    //         if (_result == 0) {
    //             console.log("   -- StorageSetterRestricted already present and initialization is cleared. Skipping");
    //             return;
    //         } else {
    //             console.log(
    //                 "   -- StorageSetterRestricted already present, but initialization is not cleared. Re-upgrading."
    //             );
    //         }
    //     } catch {
    //         console.log("   -- StorageSetterRestricted not present. Will upgrade.");
    //     }

    //     // Execute
    //     _execL1SafeTx(_to, _calldata, _approveToo);
    // }

    // function execSafeTx_L1_02(
    //     address _to,
    //     bytes memory _calldata,
    //     bool _approveToo,
    //     address _proxyAddress,
    //     string memory _expectedVersion
    // ) public {
    //     // Skip if upgrade already happened
    //     try ISemver(_proxyAddress).version() returns (string memory _result) {
    //         console.log("   -- _result: ", _result);
    //         if (compareStrings(_expectedVersion, _result)) {
    //             console.log("   -- version() matches expected. Upgrade already happened, so will skip");
    //             return;
    //         } else {
    //             console.log("   -- version() mismatch. Upgrade did not happen yet, so will proceed.");
    //         }
    //     } catch {
    //         console.log("   -- version() not present. Will upgrade.");
    //     }

    //     // Execute
    //     _execL1SafeTx(_to, _calldata, _approveToo);
    // }

    // function execSafeTx_L2_02_VCheck(
    //     address _to,
    //     bytes memory _calldata,
    //     bool _approveToo,
    //     address _proxyAddress,
    //     string memory _expectedVersion
    // ) public {
    //     // Skip if upgrade already happened
    //     try ISemver(_proxyAddress).version() returns (string memory _result) {
    //         console.log("   -- _result: ", _result);
    //         if (compareStrings(_expectedVersion, _result)) {
    //             console.log("   -- version() matches expected. Upgrade already happened, so will skip");
    //             return;
    //         } else {
    //             console.log("   -- version() mismatch. Upgrade did not happen yet, so will proceed.");
    //         }
    //     } catch {
    //         console.log("   -- version() not present. Will upgrade.");
    //     }
    //     _execL2SafeTx(_to, _calldata, _approveToo);
    // }

    // function execSafeTx_L2_03_SSCheck(
    //     address _to,
    //     bytes memory _calldata,
    //     bool _approveToo,
    //     address _proxyAddress
    // ) public {
    //     // Skip if StorageSetterRestricted is already there and initialization was cleared
    //     try StorageSetterRestricted(_proxyAddress).getUint(0) returns (uint256 _result) {
    //         console.log("   -- _result: ", _result);
    //         if (_result == 0) {
    //             console.log("   -- StorageSetterRestricted already present and initialization is cleared. Skipping");
    //             return;
    //         } else {
    //             console.log(
    //                 "   -- StorageSetterRestricted already present, but initialization is not cleared. Re-upgrading."
    //             );
    //         }
    //     } catch {
    //         console.log("   -- StorageSetterRestricted not present. Will upgrade.");
    //     }

    //     // Execute
    //     _execL2SafeTx(_to, _calldata, _approveToo);
    // }

    // function execSafeTx_L2_03_VCheck(
    //     address _to,
    //     bytes memory _calldata,
    //     bool _approveToo,
    //     address _proxyAddress,
    //     string memory _expectedVersion
    // ) public {
    //     // Skip if upgrade already happened
    //     try ISemver(_proxyAddress).version() returns (string memory _result) {
    //         console.log("   -- _result: ", _result);
    //         if (compareStrings(_expectedVersion, _result)) {
    //             console.log("   -- version() matches expected. Upgrade already happened, so will skip");
    //             return;
    //         } else {
    //             console.log("   -- version() mismatch. Upgrade did not happen yet, so will proceed.");
    //         }
    //     } catch {
    //         console.log("   -- version() not present. Will upgrade.");
    //     }

    //     _execL2SafeTx(_to, _calldata, _approveToo);
    // }

    // function _execL1SafeTx(address _to, bytes memory _calldata, bool _approveToo) internal {
    //     _execSafeTx(_to, _calldata, _approveToo, l1Safe, 0);
    // }

    // function _execL2SafeTx(address _to, bytes memory _calldata, bool _approveToo) internal {
    //     _execSafeTx(_to, _calldata, _approveToo, l2Safe, 0);
    // }

    // function execL2SafeTestTx(IGnosisSafe _safe) public {
    //     // Sent gas to a test address
    //     address _to = address(0);
    //     bytes memory _calldata = "";

    //     _execSafeTx(_to, _calldata, false, _safe, 100 gwei);
    // }

    // function execL2SafeSpecifiedSafeTx(
    //     address _to,
    //     bytes memory _calldata,
    //     bool _approveToo,
    //     IGnosisSafe _safe
    // ) public {
    //     _execSafeTx(_to, _calldata, false, _safe, 0);
    // }

    // function _execSafeTx(
    //     address _to,
    //     bytes memory _calldata,
    //     bool _approveToo,
    //     IGnosisSafe _safe,
    //     uint256 _value
    // ) internal {
    //     // See
    //     // https://user-images.githubusercontent.com/33375223/211921017-b57ae2f3-0d33-4265-a87d-945a69a77ba6.png

    //     // Get the nonce
    //     uint256 _nonce = _safe.nonce();

    //     // Encode the tx
    //     bytes memory _encodedTxData = _safe.encodeTransactionData(
    //         _to,
    //         _value,
    //         _calldata,
    //         SafeOps.Operation.Call,
    //         0,
    //         0,
    //         0,
    //         address(0),
    //         payable(address(0)),
    //         _nonce
    //     );

    //     // Sign the encoded tx
    //     bytes memory signature;
    //     if (msg.sender == junkDeployerAddress) {
    //         // If the caller is not a signer
    //         console.log("   -- Caller is not a signer");
    //         (uint8 v, bytes32 r, bytes32 s) = vm.sign(junkDeployerPk, keccak256(_encodedTxData));
    //         signature = abi.encodePacked(r, s, v); // Note order is reversed here
    //         console.log("-------- Signature --------");
    //         console.logBytes(signature);
    //     } else {
    //         // This is the signature format used if the caller is also the signer.
    //         console.log("   -- Caller is a signer");
    //         signature = abi.encodePacked(uint256(uint160(junkDeployerAddress)), bytes32(0), uint8(1));
    //     }

    //     // (Optional) Approve the tx hash
    //     if (_approveToo) {
    //         // Have to static call here due to compiler issues
    //         (bool _success, bytes memory _returnData) = address(_safe).staticcall(
    //             abi.encodeWithSelector(
    //                 _safe.getTransactionHash.selector,
    //                 _to,
    //                 0,
    //                 _calldata,
    //                 SafeOps.Operation.Call,
    //                 0,
    //                 0,
    //                 0,
    //                 address(0),
    //                 payable(address(0)),
    //                 _nonce
    //             )
    //         );
    //         require(_success, "approveAndExecSafeTx failed");
    //         _safeTxHash = abi.decode(_returnData, (bytes32));
    //         console.logBytes(_returnData);

    //         // Approve the hash
    //         _safe.approveHash(_safeTxHash);
    //     }

    //     // Execute the transaction
    //     _safe.execTransaction({
    //         to: _to,
    //         value: _value,
    //         data: _calldata,
    //         operation: SafeOps.Operation.Call,
    //         safeTxGas: 0,
    //         baseGas: 0,
    //         gasPrice: 0,
    //         gasToken: address(0),
    //         refundReceiver: payable(address(0)),
    //         signatures: signature
    //     });
    // }

    // function compareStrings(string memory _a, string memory _b) public pure returns (bool) {
    //     return keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
    // }
}
