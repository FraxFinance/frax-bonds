// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ============================ FXBFactory ============================
// ====================================================================
// Factory contract for FXB tokens
// Frax Finance: https://github.com/FraxFinance

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { BokkyPooBahsDateTimeLibrary as DateTimeLibrary } from "./utils/BokkyPooBahsDateTimeLibrary.sol";
import { FXB } from "./FXB.sol";
import { FraxBeacon } from "./FraxBeacon.sol";
import { FraxBeaconProxy } from "./FraxBeaconProxy.sol";

/// @title FXBFactory
/// @notice Deploys FXB ERC20 contracts
/// @dev "FXB" and "bond" are interchangeable
/// @dev https://github.com/FraxFinance/frax-bonds
contract FXBFactory is Ownable2StepUpgradeable {
    using Strings for uint256;

    // =============================================================================================
    // Storage
    // =============================================================================================

    /// @notice Address of the beacon which contains the FXB implementation address
    address public beacon;

    /// @notice Address of the token backing the FXB
    address public token;

    /// @notice Array of bond addresses
    address[] public fxbs;

    /// @notice Whether a given address is a bond
    mapping(address _fxb => bool _isFxb) public isFxb;

    /// @notice Whether a given timestamp has a bond deployed
    mapping(uint256 _timestamp => bool _isFxb) public isTimestampFxb;

    // =============================================================================================
    // Initialize
    // =============================================================================================

    constructor() {
        _disableInitializers();
    }

    /// @notice Constructor
    /// @param _owner The owner of this contract
    /// @param _token The address of the redeemable token (e.g., legacy FRAX)
    function initialize(address _owner, address _token) external initializer {
        address implementation = address(new FXB());
        beacon = address(new FraxBeacon({ _owner: _owner, _initialImplementation: implementation }));

        token = _token;

        // Fraxtal-sourced: can be redeemed for the underlying token on Fraxtal
        // 20251231
        isFxb[0xacA9A33698cF96413A40A4eB9E87906ff40fC6CA] = true;
        fxbs.push(0xacA9A33698cF96413A40A4eB9E87906ff40fC6CA);
        isTimestampFxb[1_767_225_600] = true;

        // 20271231
        isFxb[0x6c9f4E6089c8890AfEE2bcBA364C2712f88fA818] = true;
        fxbs.push(0x6c9f4E6089c8890AfEE2bcBA364C2712f88fA818);
        isTimestampFxb[1_830_297_600] = true;

        // 20291231
        isFxb[0xF1e2b576aF4C6a7eE966b14C810b772391e92153] = true;
        fxbs.push(0xF1e2b576aF4C6a7eE966b14C810b772391e92153);
        isTimestampFxb[1_893_456_000] = true;

        // 20551231
        isFxb[0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83] = true;
        fxbs.push(0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83);
        isTimestampFxb[2_713_910_400] = true;

        __Ownable2Step_init();
        _transferOwnership(_owner);
    }

    /// @notice Returns the semantic version of this contract
    /// @return _major The major version
    /// @return _minor The minor version
    /// @return _patch The patch version
    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        return (2, 0, 0);
    }

    // =============================================================================================
    // View functions
    // =============================================================================================

    /// @notice Returns the total number of bonds addresses created
    /// @return Number of bonds addresses created
    function fxbsLength() public view returns (uint256) {
        return fxbs.length;
    }

    /// @notice Generates the bond symbol and name in the (identical) format FXBYYYYMMDD
    /// @param _maturityTimestamp Date the bond will mature
    /// @return metadata The bond name/symbol
    function _generateFxbMetadata(uint256 _maturityTimestamp) internal pure returns (string memory metadata) {
        // Maturity date
        uint256 month = DateTimeLibrary.getMonth(_maturityTimestamp);
        uint256 day = DateTimeLibrary.getDay(_maturityTimestamp);
        uint256 year = DateTimeLibrary.getYear(_maturityTimestamp);

        // Generate the month part of the metadata
        string memory monthString;
        if (month > 9) {
            monthString = month.toString();
        } else {
            monthString = string.concat("0", month.toString());
        }

        // Generate the day part of the metadata
        string memory dayString;
        if (day > 9) {
            dayString = day.toString();
        } else {
            dayString = string.concat("0", day.toString());
        }

        // Assemble all the strings into one
        metadata = string(abi.encodePacked("FXB", year.toString(), monthString, dayString));
    }

    // =============================================================================================
    // Configurations / Privileged functions
    // =============================================================================================

    /// @notice Generates a new bond contract
    /// @param _maturityTimestamp Date the bond will mature and be redeemable
    /// @return fxb The address of the new bond
    /// @return id The id of the new bond
    function createFxbContract(uint256 _maturityTimestamp) external onlyOwner returns (address fxb, uint256 id) {
        // Round the timestamp down to 00:00 UTC
        uint256 _coercedMaturityTimestamp = (_maturityTimestamp / 1 days) * 1 days;

        // Make sure the bond didn't expire
        if (_coercedMaturityTimestamp <= block.timestamp) {
            revert BondMaturityAlreadyExpired();
        }

        // Ensure bond maturity is unique
        if (isTimestampFxb[_coercedMaturityTimestamp]) {
            revert BondMaturityAlreadyExists();
        }

        // Set the bond id
        id = fxbsLength();

        // Use the day before for the name/symbol
        uint256 _coercedMaturityTimestampDayBefore = _coercedMaturityTimestamp - 1 days;

        // Get the new symbol and name
        string memory metadata = _generateFxbMetadata({ _maturityTimestamp: _coercedMaturityTimestampDayBefore });

        // Create the new contract
        bytes memory data = abi.encodeCall(FXB.initialize, (metadata, token, _coercedMaturityTimestamp));
        fxb = address(new FraxBeaconProxy({ beacon: beacon, data: data }));

        // Add the new bond address to the array and update the mapping
        fxbs.push(fxb);
        isFxb[fxb] = true;

        // Mark the maturity timestamp as having a bond associated with it
        isTimestampFxb[_coercedMaturityTimestamp] = true;

        emit BondCreated({
            fxb: fxb,
            id: id,
            metadata: metadata,
            token: token,
            maturityTimestamp: _coercedMaturityTimestamp
        });
    }

    /// @notice Sets the address of the redeemable token (e.g., legacy FRAX)
    /// @param _token The address of the redeemable token
    function setToken(address _token) external onlyOwner {
        token = _token;
    }

    // ==============================================================================
    // Events
    // ==============================================================================

    /// @notice Emitted when a new bond is created
    /// @param fxb Address of the bond
    /// @param id The ID of the bond
    /// @param metadata Name and symbol of the bond
    /// @param token Address of the redeemable token (e.g., legacy FRAX)
    /// @param maturityTimestamp Date the bond will mature
    event BondCreated(address fxb, uint256 id, string metadata, address token, uint256 maturityTimestamp);

    // ==============================================================================
    // Errors
    // ==============================================================================

    /// @notice Thrown when an invalid month number is passed
    error InvalidMonthNumber();

    /// @notice Thrown when a bond with the same maturity already exists
    error BondMaturityAlreadyExists();

    /// @notice Thrown when attempting to create a bond with an expiration before the current time
    error BondMaturityAlreadyExpired();
}
