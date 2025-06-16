pragma solidity ^0.8.23;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

/**
 * @title FraxBeaconProxy
 * @notice Beacon Proxy contract that uses a beacon to determine the implementation address
 * @dev This contract is used to create proxies that delegate calls to an implementation defined by a beacon
 */
contract FraxBeaconProxy is BeaconProxy {
    /**
     * @notice Constructor that initializes the beacon proxy with the beacon address and initialization data
     * @param beacon The address of the beacon contract
     * @param data The initialization data to be passed to the implementation
     */
    constructor(address beacon, bytes memory data) BeaconProxy(beacon, data) {}

    /**
     * @notice Returns the beacon address
     * @return The address of the beacon
     */
    function getBeacon() external view returns (address) {
        return _getBeacon();
    }

    /// @dev added to remove warning.  Same functionality found in OZ Proxy.sol.
    fallback() external payable override {
        _fallback();
    }
}
