// SPDX-License-Identifier: ISC
pragma solidity ^0.8.0;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ============================ FXB_LFRAX =============================
// ====================================================================
// Frax Bond token (FXB) ERC20 contract. A FXB is sold at a discount and redeemed 1-to-1 for collateral token (Legacy Frax / LFRAX here) at a later date.
// Upgrades an already-existing frxUSD-filled FXB to use Legacy Frax Dollar
// Frax Finance: https://github.com/FraxFinance

import { IERC20, ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712StoragePad } from "src/contracts/utils/EIP712StoragePad.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable-5/proxy/utils/Initializable.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IERC20PermitPermissionedOptiMintable } from "src/contracts/interfaces/IERC20PermitPermissionedOptiMintable.sol";
import { IERC5267 } from "@openzeppelin/contracts/interfaces/IERC5267.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { ShortStrings, ShortString } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Timelock2Step } from "frax-std/access-control/v2/Timelock2Step.sol";

/// @title FXB
/// @notice  The FXB token can be redeemed for 1 FRAX at a later date. Created via factory.
/// @dev https://github.com/FraxFinance/frax-bonds
contract FXB_LFRAX is Initializable, ERC20, IERC20Permit, IERC5267, EIP712StoragePad, Nonces {
    using ShortStrings for *;

    // =============================================================================================
    // Storage
    // =============================================================================================

    // ERC20Permit
    // =======================================

    // mapping(address => Counters.Counter) private _nonces;

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // FXB
    // =======================================

    /// @notice Total amount of FXB minted
    uint256 public totalFxbMinted;

    /// @notice Total amount of FXB redeemed
    uint256 public totalFxbRedeemed;

    /// @notice Address of the factory to create the FXB
    address public factory;

    /// @notice The collateral token contract
    IERC20 public token;

    /// @notice The frxUSD token contract
    IERC20PermitPermissionedOptiMintable public frxUSD;

    /// @notice Timestamp of bond maturity
    uint256 public MATURITY_TIMESTAMP;

    // EIP721
    // =======================================
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    string private _nameFallback;
    string private _versionFallback;

    bytes32 private _cachedDomainSeparator;
    uint256 private _cachedChainId;
    address private _cachedThis;

    bytes32 private _hashedName;
    bytes32 private _hashedVersion;

    ShortString private _SStrName;
    ShortString private _SStrVersion;

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
    // Constructor & Initializer
    // =============================================================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC20("JUNK", "JUNK") {
        _disableInitializers();
    }

    /// @notice Called by the factory
    /// @param _nameAndSymbol The name and symbol of the bond
    /// @param _collatToken The address of the collateral token
    /// @param _frxUSD The address of the frxUSD token
    /// @param _maturityTimestamp Timestamp the bond will mature and be redeemable
    function initialize(
        string memory _nameAndSymbol,
        address _collatToken,
        address _frxUSD,
        uint256 _maturityTimestamp,
        address _factory
    ) public initializer {
        string memory _thisVersion = "1.2.0";
        factory = _factory;

        // __ERC20_init(_nameAndSymbol, _nameAndSymbol);
        // __ERC20Permit_init(_nameAndSymbol);

        // Overwrite ERC20 _name and _symbol
        // NOTE: NOT really needed if you are writing over an existing contract and the name isn't changing.
        //--------------------------------------
        // Make sure _nameAndSymbol is below 31 bytes
        uint256 _nameAndSymbolLength = bytes(_nameAndSymbol).length;
        if (_nameAndSymbolLength >= 32) {
            revert("Name and/or symbol must be lt 32 bytes");
        }

        // Write to the storage slots
        // https://ethereum.stackexchange.com/questions/126269/how-to-store-and-retrieve-string-which-is-more-than-32-bytesor-could-be-less-th
        assembly {
            // If string length <= 31 we store a short array
            // length storage variable layout :
            // bytes 0 - 31 : string data
            // byte 32 : length * 2
            // data storage variable is UNUSED in this case
            sstore(3, or(mload(add(_nameAndSymbol, 0x20)), mul(_nameAndSymbolLength, 2)))
            sstore(4, or(mload(add(_nameAndSymbol, 0x20)), mul(_nameAndSymbolLength, 2)))
        }

        // Set EIP712 variables
        //--------------------------------------
        _SStrName = _nameAndSymbol.toShortStringWithFallback(_nameFallback);
        _SStrVersion = _thisVersion.toShortStringWithFallback(_versionFallback);
        _hashedName = keccak256(bytes(_nameAndSymbol));
        _hashedVersion = keccak256(bytes(_thisVersion));
        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);

        // Set the collateral token address
        token = IERC20(_collatToken);

        // Set the frxUSD address
        frxUSD = IERC20PermitPermissionedOptiMintable(_frxUSD);

        // Set the maturity timestamp
        MATURITY_TIMESTAMP = _maturityTimestamp;

        // Burn existing frxUSD
        // Note: You will need to fill this with collateral token 1:1 eventually for the redemptions to work.
        IERC20PermitPermissionedOptiMintable(_frxUSD).burn(
            IERC20PermitPermissionedOptiMintable(_frxUSD).balanceOf(address(this))
        );
    }

    // =============================================================================================
    // ========== EIP712 FUNCTIONS ==========
    // =============================================================================================

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(_TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev See {EIP-5267}.
     *
     * _Available since v4.9._
     */
    function eip712Domain()
        public
        view
        virtual
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory versionOut,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f", // 01111
            _SStrName.toStringWithFallback(_nameFallback),
            _SStrVersion.toStringWithFallback(_versionFallback),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    /* ========== ERC20Permit FUNCTIONS ========== */

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @inheritdoc IERC20Permit
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _approve(owner, spender, value);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    function nonces(address owner) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    // =============================================================================================
    // View functions
    // =============================================================================================

    /// @notice Returns summary information about the bond
    /// @return BondInfo Summary of the bond
    function bondInfo() external view returns (BondInfo memory) {
        return BondInfo({ symbol: symbol(), name: name(), maturityTimestamp: MATURITY_TIMESTAMP });
    }

    /// @notice Returns a boolean representing whether a bond can be redeemed
    /// @dev timelock (team msig) has rights to burn FXB before maturity
    /// @return _isRedeemable If the bond is redeemable
    function isRedeemable() public view returns (bool _isRedeemable) {
        _isRedeemable =
            msg.sender == Timelock2Step(factory).timelockAddress() ||
            (block.timestamp >= MATURITY_TIMESTAMP);
    }

    /// @notice Returns the semantic version of this contract
    /// @return _major The major version
    /// @return _minor The minor version
    /// @return _patch The patch version
    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        return (1, 2, 0);
    }

    // =============================================================================================
    // Public functions
    // =============================================================================================

    /// @notice Mints a specified amount of tokens to the account, requires caller to approve on the collateral token contract in an amount equal to the minted amount
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

        // Interactions: Take 1-to-1 collateral token from the user
        token.transferFrom(msg.sender, address(this), value);
    }

    /// @notice Redeems FXB 1-to-1 for collateral token
    /// @dev Supports OZ 5.0 interfacing with named variable arguments
    /// @param to Recipient of redeemed collateral token
    /// @param value Amount to redeem
    function burn(address to, uint256 value) external {
        // Require bond has matured or owner is burning
        if (!isRedeemable()) revert BondNotRedeemable();

        // Make sure you burning a nonzero amount
        if (value == 0) revert ZeroAmount();

        // Check if there is enough collateral (.transfer would throw an error anyways, but this is more verbose)
        if (token.balanceOf(address(this)) < value) revert InsufficientCollateral();

        // Effects: Update redeem tracking
        totalFxbRedeemed += value;

        // Effects: Burn the FXB from the user
        _burn({ account: msg.sender, value: value });

        // Interactions: Give collateral token to the recipient
        token.transfer(to, value);
    }

    // ==============================================================================
    // Errors
    // ==============================================================================

    /// @notice Thrown if the bond hasn't matured yet, or redeeming is paused
    error BondNotRedeemable();

    /// @notice Thrown if there is not an enough token collateral
    error InsufficientCollateral();

    /// @notice Thrown if attempting to mint / burn zero tokens
    error ZeroAmount();
}
