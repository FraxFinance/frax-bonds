pragma solidity ^0.8.23;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =============================== FXB ================================
// ====================================================================
// Frax Bond token (FXB) ERC20 contract. A FXB is sold at a discount and redeemed 1-to-1 for collateral token at a later date.
// Frax Finance: https://github.com/FraxFinance

import { ERC20Upgradeable, IERC20 } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20PermitUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title FXB
/// @notice The FXB token can be redeemed for an equivalent collateral token at a later date. Created via factory.
/// @dev https://github.com/FraxFinance/frax-bonds
contract FXB is ERC20Upgradeable, ERC20PermitUpgradeable {
    // =============================================================================================
    // Storage
    // =============================================================================================

    /// @notice Address of the factory to create the FXB
    address public factory;

    /// @notice Token redeemable upon maturity
    /// @dev previously frxUsd in v1.1.0
    IERC20 public token;

    /// @notice Timestamp of bond maturity
    uint256 public MATURITY_TIMESTAMP;

    /// @notice Total amount of FXB minted
    uint256 public totalFxbMinted;

    /// @notice Total amount of FXB redeemed
    uint256 public totalFxbRedeemed;

    // =============================================================================================
    // Structs
    // =============================================================================================

    /// @notice Bond Information
    /// @param symbol The symbol of the bond
    /// @param name The name of the bond
    /// @param maturityTimestamp Timestamp the bond will mature
    struct BondInfo {
        string symbol;
        string name;
        uint256 maturityTimestamp;
    }

    // =============================================================================================
    // Initalization & Constructor
    // =============================================================================================

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the FXB contract
    /// @dev Called by the factory
    /// @param _metadata The name and symbol of the bond
    /// @param _token The address of the redeemable token
    /// @param _maturityTimestamp Timestamp the bond will mature and be redeemable
    function initialize(string memory _metadata, address _token, uint256 _maturityTimestamp) external initializer {
        // Initialize the ERC20 and ERC20Permit with the metadata
        __ERC20_init(_metadata, _metadata);
        __ERC20Permit_init(_metadata);

        // Set the factory address
        factory = msg.sender;

        token = IERC20(_token);

        // Set the maturity timestamp
        MATURITY_TIMESTAMP = _maturityTimestamp;
    }

    // =============================================================================================
    // View functions
    // =============================================================================================

    /// @dev supports legacy (v1.1.0) interface
    function FRAX() external view returns (IERC20) {
        return token;
    }

    /// @notice Returns summary information about the bond
    /// @return BondInfo Summary of the bond
    function bondInfo() external view returns (BondInfo memory) {
        return BondInfo({ symbol: symbol(), name: name(), maturityTimestamp: MATURITY_TIMESTAMP });
    }

    /// @notice Returns a boolean representing whether a bond can be redeemed
    /// @dev Frax team msig has rights to burn FXB before maturity
    /// @return _isRedeemable If the bond is redeemable
    function isRedeemable() public view returns (bool _isRedeemable) {
        _isRedeemable = msg.sender == Ownable(factory).owner() || (block.timestamp >= MATURITY_TIMESTAMP);
    }

    /// @notice Returns the semantic version of this contract
    /// @return _major The major version
    /// @return _minor The minor version
    /// @return _patch The patch version
    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        return (2, 0, 0);
    }

    // =============================================================================================
    // Public functions
    // =============================================================================================

    /// @notice Mints a specified amount of tokens to the account, requires caller to approve on the FRAX contract in an amount equal to the minted amount
    /// @dev Supports OZ 5.0 interfacing with named variable arguments
    /// @param account The account to receive minted tokens
    /// @param value The amount of the token to mint
    function mint(address account, uint256 value) external {
        // NOTE: Allow minting after expiry

        // Make sure minting an amount
        if (value == 0) revert ZeroAmount();

        // Effects: update mint tracking
        totalFxbMinted += value;

        // Effects: Give the FXB to the recipient
        _mint({ account: account, value: value });

        // Interactions: Take 1-to-1 FRAX from the user
        token.transferFrom(msg.sender, address(this), value);
    }

    /// @notice Redeems FXB 1-to-1 for token
    /// @dev Supports OZ 5.0 interfacing with named variable arguments
    /// @param to Recipient of redeemed token
    /// @param value Amount to redeem
    function burn(address to, uint256 value) external {
        // Require bond has matured or owner is burning
        if (!isRedeemable()) revert BondNotRedeemable();

        // Make sure you burning a nonzero amount
        if (value == 0) revert ZeroAmount();

        // Effects: Update redeem tracking
        totalFxbRedeemed += value;

        // Effects: Burn the FXB from the user
        _burn({ account: msg.sender, value: value });

        // Interactions: Give token to the recipient
        token.transfer(to, value);
    }

    // ==============================================================================
    // Errors
    // ==============================================================================

    /// @notice Thrown if the bond hasn't matured yet, or redeeming is paused
    error BondNotRedeemable();

    /// @notice Thrown if attempting to mint / burn zero tokens
    error ZeroAmount();
}
