// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { IERC1967 } from "@openzeppelin/contracts/interfaces/IERC1967.sol";

/**
 * @dev Interface for {TransparentUpgradeableProxy}. In order to implement transparency, {TransparentUpgradeableProxy}
 * does not implement this interface directly, and its upgradeability mechanism is implemented by an internal dispatch
 * mechanism. The compiler is unaware that these functions are implemented by {TransparentUpgradeableProxy} and will not
 * include them in the ABI so this interface must be used to interact with it.
 */
interface ITransparentUpgradeableProxy is IERC1967 {
    /// @dev See {UUPSUpgradeable-upgradeToAndCall}
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
    function changeAdmin(address newAdmin) external;
}

/// @notice Equivalent to the OZ 5.0 version of TransparentUpgradeableProxy
/// @dev This version:
///     - does not deploy a ProxyAdmin upon construction, as it is not needed.
///     - adds views to access the implementation and admin slots without calling through the proxyAdmin.
///     - adds a function to change the admin
contract FraxUpgradeableProxy is ERC1967Proxy {
    /// @notice Error thrown when a non-admin tries to call the upgrade function.
    error ProxyDeniedAdminAccess();

    constructor(address _logic, address _initialAdmin, bytes memory _data) ERC1967Proxy(_logic, _data) {
        // Set the storage value and emit an event for ERC-1967 compatibility
        ERC1967Utils.changeAdmin(_initialAdmin);
    }

    /**
     * @dev If caller is the admin process the call internally, otherwise transparently fallback to the proxy behavior.
     */
    function _fallback() internal virtual override {
        if (msg.sender == ERC1967Utils.getAdmin()) {
            if (msg.sig == ITransparentUpgradeableProxy.changeAdmin.selector) {
                _changeAdmin();
            } else if (msg.sig == ITransparentUpgradeableProxy.upgradeToAndCall.selector) {
                _dispatchUpgradeToAndCall();
            } else {
                revert ProxyDeniedAdminAccess();
            }
        } else {
            super._fallback();
        }
    }

    /**
     * @dev Upgrade the implementation of the proxy. See {ERC1967Utils-upgradeToAndCall}.
     *
     * Requirements:
     *
     * - If `data` is empty, `msg.value` must be zero.
     */
    function _dispatchUpgradeToAndCall() private {
        (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
    }

    /// @dev Change the admin of the proxy.  This can be accessed if the admin is not already the ProxyAdmin,
    /// as the ProxyAdmin does not contain a `changeAdmin` function.
    function _changeAdmin() private {
        address newAdmin = abi.decode(msg.data[4:], (address));
        ERC1967Utils.changeAdmin(newAdmin);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @dev Returns the current admin address.
     */
    function admin() external view returns (address) {
        return ERC1967Utils.getAdmin();
    }
}
