// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =========================== FraxBeacon =============================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IBeacon } from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

/**
 * @title FraxBeacon
 * @notice Abstract Beacon Contract used by proxy factories
 * @dev The proxy deployments will call `implementation()` on this address to get the address
 *      to which they will delegate call into. Upgrading this pointer implicitly upgrades all
 *      of the proxy contracts deployed by the factory
 */
contract FraxBeacon is IBeacon, Ownable2Step {
    address public implementation;

    constructor(address _owner, address _initialImplementation) Ownable(_owner) {
        _setImplementation(_initialImplementation);
    }

    /**
     * @notice Admin gated function to change the implementation contract which the
     *         beacon tells the proxies to forward calls to
     * @param _newImplementation The new Implementation address for all proxies deployed
     *                           via the factory
     */
    function setImplementation(address _newImplementation) external onlyOwner {
        _setImplementation(_newImplementation);
    }

    /**
     * @notice Internal helper function to set the implementation in the beacon
     *         intended to be used in construction of the child contract
     * @param _newImplementation The new Implementation address for all proxies deployed
     *                           via the factory
     */
    function _setImplementation(address _newImplementation) internal {
        emit FraxBeaconImplementationUpdated(implementation, _newImplementation);
        implementation = _newImplementation;
    }

    /**
     * @notice Event emitted when the beacons implementation is changed
     * @param oldImplementation The address of the old implementation
     * @param newImplementation The address of the new implementation
     */
    event FraxBeaconImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);
}
