// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================= SlippageAuction ==========================
// ====================================================================
// Slippage auction to sell tokens over time.  Both tokens must be 18 decimals.
// It has 3 parameters:
// - amount of sell token to auction
// - slippage per token bought
// - price decrease per day.
// For this we can calculate the time the auction will operate at the market price.
// Example:
// - We auction 10M
// - We pick a slippage such that a 100k buy will result in 0.1% slippage
// => 10M = 100x100k, so total price impact during the auction will be 20% (price impact is twice the slippage)
// - We lower the price 1% per day
// => the auction will be at the market price for at least 20 days.

// Frax Finance: https://github.com/FraxFinance

// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================== Timelock2Step ===========================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author
// Drake Evans: https://github.com/DrakeEvans

// Reviewers
// Dennis: https://github.com/denett

// ====================================================================

/// @title Timelock2Step
/// @author Drake Evans (Frax Finance) https://github.com/drakeevans
/// @dev Inspired by OpenZeppelin's Ownable2Step contract
/// @notice  An abstract contract which contains 2-step transfer and renounce logic for a timelock address
abstract contract Timelock2Step {
    /// @notice The pending timelock address
    address public pendingTimelockAddress;

    /// @notice The current timelock address
    address public timelockAddress;

    constructor(address _timelockAddress) {
        timelockAddress = _timelockAddress;
    }

    // ============================================================================================
    // Functions: External Functions
    // ============================================================================================

    /// @notice The ```transferTimelock``` function initiates the timelock transfer
    /// @dev Must be called by the current timelock
    /// @param _newTimelock The address of the nominated (pending) timelock
    function transferTimelock(address _newTimelock) external virtual {
        _requireSenderIsTimelock();
        _transferTimelock(_newTimelock);
    }

    /// @notice The ```acceptTransferTimelock``` function completes the timelock transfer
    /// @dev Must be called by the pending timelock
    function acceptTransferTimelock() external virtual {
        _requireSenderIsPendingTimelock();
        _acceptTransferTimelock();
    }

    /// @notice The ```renounceTimelock``` function renounces the timelock after setting pending timelock to current timelock
    /// @dev Pending timelock must be set to current timelock before renouncing, creating a 2-step renounce process
    function renounceTimelock() external virtual {
        _requireSenderIsTimelock();
        _requireSenderIsPendingTimelock();
        _transferTimelock(address(0));
        _setTimelock(address(0));
    }

    // ============================================================================================
    // Functions: Internal Actions
    // ============================================================================================

    /// @notice The ```_transferTimelock``` function initiates the timelock transfer
    /// @dev This function is to be implemented by a public function
    /// @param _newTimelock The address of the nominated (pending) timelock
    function _transferTimelock(address _newTimelock) internal {
        pendingTimelockAddress = _newTimelock;
        emit TimelockTransferStarted(timelockAddress, _newTimelock);
    }

    /// @notice The ```_acceptTransferTimelock``` function completes the timelock transfer
    /// @dev This function is to be implemented by a public function
    function _acceptTransferTimelock() internal {
        pendingTimelockAddress = address(0);
        _setTimelock(msg.sender);
    }

    /// @notice The ```_setTimelock``` function sets the timelock address
    /// @dev This function is to be implemented by a public function
    /// @param _newTimelock The address of the new timelock
    function _setTimelock(address _newTimelock) internal {
        emit TimelockTransferred(timelockAddress, _newTimelock);
        timelockAddress = _newTimelock;
    }

    // ============================================================================================
    // Functions: Internal Checks
    // ============================================================================================

    /// @notice The ```_isTimelock``` function checks if _address is current timelock address
    /// @param _address The address to check against the timelock
    /// @return Whether or not msg.sender is current timelock address
    function _isTimelock(address _address) internal view returns (bool) {
        return _address == timelockAddress;
    }

    /// @notice The ```_requireIsTimelock``` function reverts if _address is not current timelock address
    /// @param _address The address to check against the timelock
    function _requireIsTimelock(address _address) internal view {
        if (!_isTimelock(_address)) revert AddressIsNotTimelock(timelockAddress, _address);
    }

    /// @notice The ```_requireSenderIsTimelock``` function reverts if msg.sender is not current timelock address
    /// @dev This function is to be implemented by a public function
    function _requireSenderIsTimelock() internal view {
        _requireIsTimelock(msg.sender);
    }

    /// @notice The ```_isPendingTimelock``` function checks if the _address is pending timelock address
    /// @dev This function is to be implemented by a public function
    /// @param _address The address to check against the pending timelock
    /// @return Whether or not _address is pending timelock address
    function _isPendingTimelock(address _address) internal view returns (bool) {
        return _address == pendingTimelockAddress;
    }

    /// @notice The ```_requireIsPendingTimelock``` function reverts if the _address is not pending timelock address
    /// @dev This function is to be implemented by a public function
    /// @param _address The address to check against the pending timelock
    function _requireIsPendingTimelock(address _address) internal view {
        if (!_isPendingTimelock(_address)) revert AddressIsNotPendingTimelock(pendingTimelockAddress, _address);
    }

    /// @notice The ```_requirePendingTimelock``` function reverts if msg.sender is not pending timelock address
    /// @dev This function is to be implemented by a public function
    function _requireSenderIsPendingTimelock() internal view {
        _requireIsPendingTimelock(msg.sender);
    }

    // ============================================================================================
    // Functions: Events
    // ============================================================================================

    /// @notice The ```TimelockTransferStarted``` event is emitted when the timelock transfer is initiated
    /// @param previousTimelock The address of the previous timelock
    /// @param newTimelock The address of the new timelock
    event TimelockTransferStarted(address indexed previousTimelock, address indexed newTimelock);

    /// @notice The ```TimelockTransferred``` event is emitted when the timelock transfer is completed
    /// @param previousTimelock The address of the previous timelock
    /// @param newTimelock The address of the new timelock
    event TimelockTransferred(address indexed previousTimelock, address indexed newTimelock);

    // ============================================================================================
    // Functions: Errors
    // ============================================================================================

    /// @notice Emitted when timelock is transferred
    error AddressIsNotTimelock(address timelockAddress, address actualAddress);

    /// @notice Emitted when pending timelock is transferred
    error AddressIsNotPendingTimelock(address pendingTimelockAddress, address actualAddress);
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

/// @title SlippageAuction
/// @notice Slippage auction to sell tokens over time.
/// @dev Both tokens must be 18 decimals.
contract SlippageAuction is ReentrancyGuard, Timelock2Step {
    using SafeERC20 for IERC20;

    // ==============================================================================
    // Storage
    // ==============================================================================

    /// @notice The name of this auction
    string public name;

    /// @notice Slippage precision
    uint256 public constant PRECISION = 1e18;

    /// @notice Stored information about auctions
    Auction[] public auctions;

    /// @notice The token used for buying the sellToken
    address public immutable BUY_TOKEN;

    /// @notice The token being auctioned off
    address public immutable SELL_TOKEN;

    /// @notice Alias for BUY_TOKEN
    /// @dev Maintains UniswapV2 interface
    address public immutable token0;

    /// @notice Alias for SELL_TOKEN
    /// @notice Maintains UniswapV2 interface
    address public immutable token1;

    // ==============================================================================
    // Structs
    // ==============================================================================

    /// @notice Auction information
    /// @param amountLeft Amount of sellToken remaining to buy
    /// @param buyTokenProceeds Amount of buyToken that came in from sales
    /// @param priceLast Price of the last sale, in buyToken amount per sellToken (amount of buyToken to purchase 1e18 sellToken)
    /// @param priceMin Minimum price of 1e18 sellToken, in buyToken
    /// @param priceDecay Price decay, (wei per second), using PRECISION
    /// @param priceSlippage Slippage fraction. E.g (0.01 * PRECISION) = 1%
    /// @param lastBuyTime Time of the last sale
    /// @param expiry UNIX timestamp when the auction ends
    /// @param exited If the auction has ended
    struct Auction {
        uint128 amountLeft;
        uint128 buyTokenProceeds;
        uint128 priceLast;
        uint128 priceMin;
        uint64 priceDecay;
        uint64 priceSlippage;
        uint32 lastBuyTime;
        uint32 expiry;
        bool ended;
    }

    // ==============================================================================
    // Constructor
    // ==============================================================================

    /// @param _timelockAddress Address of the timelock/owner contract
    /// @param _buyToken The token used to buy the sellToken being auctioned off
    /// @param _sellToken The token being auctioned off
    constructor(address _timelockAddress, address _buyToken, address _sellToken) Timelock2Step(_timelockAddress) {
        name = string(abi.encodePacked("SlippageAuction: ", IERC20Metadata(_sellToken).symbol()));
        BUY_TOKEN = _buyToken;
        SELL_TOKEN = _sellToken;

        token0 = _buyToken;
        token1 = _sellToken;
    }

    // ==============================================================================
    // Views
    // ==============================================================================

    /// @notice The ```version``` function returns the semantic version of this contract
    /// @return _major The major version
    /// @return _minor The minor version
    /// @return _patch The patch version
    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        return (1, 0, 0);
    }

    /// @notice The ```getPreSlippagePrice``` function calculates the pre-slippage price from the time decay alone
    /// @param _auction The auction struct
    /// @return _price The price
    function getPreSlippagePrice(Auction memory _auction) public view returns (uint256 _price) {
        // Calculate Decay
        uint256 _decay = (_auction.priceDecay * (block.timestamp - _auction.lastBuyTime));

        // Calculate the sale price (in buyToken per sellToken), factoring in the time decay
        if (_auction.priceLast < _decay) {
            return _price = _auction.priceMin;
        } else {
            _price = _auction.priceLast - _decay;
        }

        // Never go below the minimum price
        if (_price < _auction.priceMin) _price = _auction.priceMin;
    }

    /// @notice The ```getAmountOut``` function calculates the amount of sellTokens out for a given buyToken amount
    /// @param _amountIn Amount of buyToken in
    /// @param _revertOnOverAmountLeft Whether to revert if _amountOut > amountLeft
    /// @return _amountOut Amount of sellTokens out
    /// @return _slippagePerSellToken The slippage component of the price change (in buyToken per sellToken)
    /// @return _postSlippagePrice The post-slippage price from the time decay + slippage
    function getAmountOut(
        uint256 _amountIn,
        bool _revertOnOverAmountLeft
    ) public view returns (uint256 _amountOut, uint256 _slippagePerSellToken, uint256 _postSlippagePrice) {
        uint256 _auctionNumber = auctions.length - 1;
        // Get the auction info
        Auction memory _auction = auctions[_auctionNumber];
        if (_auction.ended) revert AuctionAlreadyExited();
        if (block.timestamp >= _auction.expiry) revert AuctionExpired();

        // Calculate the sale price (in buyToken per sellToken), factoring in the time decay
        uint256 _preSlippagePrice = getPreSlippagePrice({ _auction: _auction });

        // Calculate the slippage component of the price (in buyToken per sellToken)
        _slippagePerSellToken = (_auction.priceSlippage * _amountIn) / PRECISION;

        // Calculate the output amount of sellToken, Set return value
        _amountOut = (_amountIn * PRECISION) / (_preSlippagePrice + _slippagePerSellToken);

        // Make sure you are not going over the amountLeft, set return value
        if (_amountOut > _auction.amountLeft) {
            if (_revertOnOverAmountLeft) revert InsufficientSellTokensAvailable();
            else _amountOut = _auction.amountLeft;
        }

        // Set return value
        _postSlippagePrice = _preSlippagePrice + (2 * _slippagePerSellToken); // Price impact is twice the slippage
    }

    /// @notice The ```getAmountInMax``` function calculates how many buyTokens you would need to buy out the remaining sellTokens in the auction
    /// @return _amountIn Amount of buyToken needed
    /// @return _slippagePerSellToken The slippage component of the price change (in buyToken per sellToken)
    /// @return _postSlippagePrice The post-slippage price from the time decay + slippage
    function getAmountInMax()
        external
        view
        returns (uint256 _amountIn, uint256 _slippagePerSellToken, uint256 _postSlippagePrice)
    {
        uint256 _auctionNumber = auctions.length - 1;

        // Get the auction info
        Auction memory _auction = auctions[_auctionNumber];

        // Call the internal function with amountLeft
        return _getAmountIn({ _auction: _auction, _desiredOut: _auction.amountLeft });
    }

    /// @notice The ```getAmountIn``` function calculates how many buyTokens you would need in order to obtain a given number of sellTokens
    /// @param _desiredOut The desired number of sellTokens
    /// @return _amountIn Amount of buyToken needed
    /// @return _slippagePerSellToken The slippage component of the price change (in buyToken per sellToken)
    /// @return _postSlippagePrice The post-slippage price from the time decay + slippage
    function getAmountIn(
        uint256 _desiredOut
    ) public view returns (uint256 _amountIn, uint256 _slippagePerSellToken, uint256 _postSlippagePrice) {
        uint256 _auctionNumber = auctions.length - 1;

        // Get the auction info
        Auction memory _auction = auctions[_auctionNumber];

        // Call the internal function with _desiredOut, set return values
        (_amountIn, _slippagePerSellToken, _postSlippagePrice) = _getAmountIn({
            _auction: _auction,
            _desiredOut: _desiredOut
        });
    }

    /// @notice The ```_getAmountIn``` function calculate how many buyTokens you would need to obtain a given number of sellTokens
    /// @param _auction The auction struct
    /// @return _amountIn Amount of buyToken needed
    /// @return _slippagePerSellToken The slippage component of the price change (in buyToken per sellToken)
    /// @return _postSlippagePrice The post-slippage price from the time decay + slippage
    function _getAmountIn(
        Auction memory _auction,
        uint256 _desiredOut
    ) internal view returns (uint256 _amountIn, uint256 _slippagePerSellToken, uint256 _postSlippagePrice) {
        // Do checks
        if (_auction.ended) revert AuctionAlreadyExited();
        if (block.timestamp >= _auction.expiry) revert AuctionExpired();
        if (_desiredOut > _auction.amountLeft) revert InsufficientSellTokensAvailable();

        // Calculate the sale price (in buyToken per sellToken), factoring in the time decay
        uint256 _preSlippagePrice = getPreSlippagePrice({ _auction: _auction });

        // Math in a more readable format:
        // uint256 _numerator = (_desiredOut * _preSlippagePrice) / PRECISION;
        // uint256 _denominator = (PRECISION -
        //     ((_desiredOut * uint256(_auction.priceSlippage)) / PRECISION));
        // _amountIn = (_numerator * PRECISION) / _denominator;

        // Set return params _amountIn
        _amountIn =
            (_desiredOut * _preSlippagePrice) /
            (PRECISION - (_desiredOut * uint256(_auction.priceSlippage)) / PRECISION);

        // Set return params, calculate the slippage component of the price (in buyToken per sellToken)
        _slippagePerSellToken = (_auction.priceSlippage * _amountIn) / PRECISION;
        _postSlippagePrice = _auction.priceLast + (2 * _slippagePerSellToken); // Price impact is twice the slippage
    }

    /// @notice The ```getAmountIn``` function calculates how many buyTokens you would need in order to obtain a given number of sellTokens
    /// @dev Maintains compatability with some router implementations
    /// @param amountOut The amount out of sell tokens
    /// @param tokenOut The sell token address
    /// @return _amountIn The amount of buyToken needed
    function getAmountIn(uint256 amountOut, address tokenOut) external view returns (uint256 _amountIn) {
        if (tokenOut != SELL_TOKEN) revert InvalidTokenOut();
        (_amountIn, , ) = getAmountIn({ _desiredOut: amountOut });
    }

    /// @notice The ```getAmountOut``` function calculates the amount of sellTokens out for a given buyToken amount
    /// @dev Used to maintain compatibility
    /// @param _amountIn Amount of buyToken in
    /// @param tokenIn The token being swapped in
    /// @return _amountOut Amount of sellTokens out
    function getAmountOut(uint256 _amountIn, address tokenIn) external view returns (uint256 _amountOut) {
        if (tokenIn == BUY_TOKEN) revert InvalidTokenIn();
        (_amountOut, , ) = getAmountOut({ _amountIn: _amountIn, _revertOnOverAmountLeft: false });
    }

    /// @notice Gets a struct instead of a tuple for auctions()
    /// @param _auctionNumber Auction ID
    /// @return _auctionStruct The struct of the auction
    function getAuctionStruct(uint256 _auctionNumber) external view returns (Auction memory) {
        return auctions[_auctionNumber];
    }

    /// @notice The ```auctionsLength``` function returns the length of the auctions array
    /// @return _length The length of the auctions array
    function auctionsLength() external view returns (uint256 _length) {
        _length = auctions.length;
    }

    /// @notice The ```getLatestAuction``` function returns the latest auction
    /// @dev Returns an empty struct if there are no auctions
    /// @return _latestAuction The latest auction struct
    function getLatestAuction() external view returns (Auction memory _latestAuction) {
        uint256 _length = auctions.length;
        if (_length == 0) return _latestAuction;
        _latestAuction = auctions[auctions.length - 1];
    }

    // ==============================================================================
    // Owner-only Functions
    // ==============================================================================

    /// @notice Parameters for creating an auction
    /// @dev Sender must have an allowance on sellToken
    /// @param sellAmount Amount of sellToken being sold
    /// @param priceStart Starting price of 1e18 sellToken, in buyToken
    /// @param priceMin Minimum price of 1e18 sellToken, in buyToken
    /// @param priceDecay Price decay, (wei per second), using PRECISION
    /// @param priceSlippage Slippage fraction. E.g (0.01 * PRECISION) = 1%
    /// @param expiry UNIX timestamp when the auction ends
    struct StartAuctionParams {
        uint128 sellAmount;
        uint128 priceStart;
        uint128 priceMin;
        uint64 priceDecay;
        uint64 priceSlippage;
        uint32 expiry;
    }

    /// @notice The ```startAuction``` function starts a new auction
    /// @param _params StartAuctionParams
    /// @dev Requires an erc20 allowance on the sellToken prior to calling
    function startAuction(StartAuctionParams memory _params) external nonReentrant returns (uint256 _auctionNumber) {
        _requireSenderIsTimelock();

        // Check expiry is not in the past
        if (_params.expiry < block.timestamp) revert Expired();

        // Pre-compute the auction number
        _auctionNumber = auctions.length;

        // Ensure that the previous auction, if any, has ended
        if (_auctionNumber > 0) {
            Auction memory _lastAuction = auctions[_auctionNumber - 1];
            if (_lastAuction.ended == false) revert LastAuctionStillActive();
        }

        // Create the auction
        auctions.push(
            Auction({
                priceDecay: _params.priceDecay,
                priceSlippage: _params.priceSlippage,
                amountLeft: _params.sellAmount,
                buyTokenProceeds: 0,
                priceLast: _params.priceStart,
                lastBuyTime: uint32(block.timestamp),
                priceMin: _params.priceMin,
                expiry: _params.expiry,
                ended: false
            })
        );

        emit AuctionStarted({
            auctionNumber: _auctionNumber,
            sellAmount: _params.sellAmount,
            priceStart: _params.priceStart,
            priceMin: _params.priceMin,
            priceDecay: _params.priceDecay,
            priceSlippage: _params.priceSlippage,
            expiry: _params.expiry
        });

        // Take the sellTokens from the sender
        IERC20(SELL_TOKEN).safeTransferFrom({ from: msg.sender, to: address(this), value: _params.sellAmount });
    }

    /// @notice The ```stopAuction``` function ends the auction
    /// @dev Only callable by the auction owner
    /// @return _buyProceeds Amount of buyToken obtained from the auction
    /// @return _unsoldRemaining Amount of unsold sellTokens left over
    function stopAuction() public nonReentrant returns (uint256 _buyProceeds, uint256 _unsoldRemaining) {
        _requireSenderIsTimelock();

        // Get the auction info and perform checks
        uint256 _auctionNumber = auctions.length - 1;
        Auction memory _auction = auctions[_auctionNumber];
        if (_auction.ended) revert AuctionAlreadyExited();

        // Set Return params
        _buyProceeds = IERC20(BUY_TOKEN).balanceOf({ account: address(this) });
        _unsoldRemaining = IERC20(SELL_TOKEN).balanceOf({ account: address(this) });

        _auction.ended = true;
        _auction.buyTokenProceeds = uint128(_buyProceeds);
        _auction.amountLeft = uint128(_unsoldRemaining);

        // Effects: Update state with final balances;
        auctions[_auctionNumber] = _auction;

        // Return buyToken proceeds from the auction to the sender
        IERC20(BUY_TOKEN).safeTransfer({ to: msg.sender, value: _buyProceeds });

        // Return any unsold sellToken to the sender
        IERC20(SELL_TOKEN).safeTransfer({ to: msg.sender, value: _unsoldRemaining });

        emit AuctionExited({ auctionNumber: _auctionNumber });
    }

    // ==============================================================================
    // Public Functions
    // ==============================================================================

    /// @notice The ```swap``` function swaps buyTokens for sellTokens
    /// @dev This low-level function should be called from a contract which performs important safety checks
    /// @dev Token0 is always the BUY_TOKEN, token1 is always the SELL_TOKEN
    /// @param _buyTokenOut The amount of buyTokens to receive
    /// @param _sellTokenOut The amount of sellTokens to receive
    /// @param _to The recipient of the output tokens
    /// @param _callbackData Callback data
    function swap(
        uint256 _buyTokenOut,
        uint256 _sellTokenOut,
        address _to,
        bytes memory _callbackData
    ) public nonReentrant {
        if (_buyTokenOut != 0) revert ExcessiveBuyTokenOut({ minOut: 0, actualOut: _buyTokenOut });
        if (_sellTokenOut == 0) revert InsufficientOutputAmount({ minOut: 1, actualOut: 0 });

        // Get the auction info (similar to get reserves in univ2)
        uint256 _auctionNumber = auctions.length - 1;
        Auction memory _auction = auctions[_auctionNumber];

        // Transfer tokens
        IERC20(SELL_TOKEN).safeTransfer({ to: _to, value: _sellTokenOut });

        // Callback if necessary for flash swap
        if (_callbackData.length > 0) {
            IUniswapV2Callee(_to).uniswapV2Call({
                sender: msg.sender,
                amount0: _buyTokenOut,
                amount1: _sellTokenOut,
                data: _callbackData
            });
        }

        // Calculate the amount of buyTokens in
        uint256 _buyTokenBalance = IERC20(BUY_TOKEN).balanceOf({ account: address(this) });
        uint256 _buyTokenIn = _buyTokenBalance - _auction.buyTokenProceeds;

        // Adheres to uniswap v2 interface, called here to prevent stack-too-deep error
        emit Swap({
            sender: msg.sender,
            amount0In: _buyTokenIn,
            amount1In: 0,
            amount0Out: 0,
            amount1Out: _sellTokenOut,
            to: _to
        });

        // Call the internal function with _desiredOut
        (uint256 _minAmountIn, uint256 _slippagePerSellToken, uint256 _postSlippagePrice) = _getAmountIn({
            _auction: _auction,
            _desiredOut: _sellTokenOut
        });

        // Check invariant
        if (_buyTokenIn < _minAmountIn) revert InsufficientInputAmount({ minIn: _minAmountIn, actualIn: _buyTokenIn });

        // Mutate _auction, which has the previous state
        _auction.amountLeft -= uint128(_sellTokenOut);
        _auction.buyTokenProceeds = uint128(_buyTokenBalance);
        _auction.priceLast = uint128(_postSlippagePrice);
        _auction.lastBuyTime = uint32(block.timestamp);

        // Write back to state, similar to _update in univ2
        auctions[_auctionNumber] = _auction;

        // Emit Buy event
        emit Buy({
            auctionNumber: _auctionNumber,
            buyToken: BUY_TOKEN,
            sellToken: SELL_TOKEN,
            amountIn: uint128(_buyTokenIn),
            amountOut: uint128(_sellTokenOut),
            priceLast: _auction.priceLast,
            slippagePerSellToken: uint128(_slippagePerSellToken)
        });
    }

    /// @notice The ```swapExactTokensForTokens``` function swaps an exact amount of input tokens for as many output tokens as possible
    /// @dev Must have an allowance on the BUY_TOKEN prior to invocation
    /// @dev Maintains uniV2 interface
    /// @param _amountIn The amount of buy tokens to send.
    /// @param _amountOutMin The minimum amount of sell tokens that must be received for the transaction not to revert
    /// @param _to Recipient of the output tokens
    /// @param _deadline Unix timestamp after which the transaction will revert
    /// @return _amounts The input token amount and output token amount
    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] memory, // _path
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory _amounts) {
        // Ensure deadline has not passed
        if (block.timestamp > _deadline) revert Expired();

        // Calculate the amount of sellTokens out & check invariant
        (uint256 _amountOut, , ) = getAmountOut({ _amountIn: _amountIn, _revertOnOverAmountLeft: true });
        if (_amountOut < _amountOutMin) {
            revert InsufficientOutputAmount({ minOut: _amountOutMin, actualOut: _amountOut });
        }
        // Interactions: Transfer buyTokens to the contract
        IERC20(BUY_TOKEN).safeTransferFrom({ from: msg.sender, to: address(this), value: _amountIn });

        // Call the internal swap function
        swap({ _buyTokenOut: 0, _sellTokenOut: _amountOut, _to: _to, _callbackData: new bytes(0) });

        // Set return values
        _amounts = new uint256[](2);
        _amounts[0] = _amountIn;
        _amounts[1] = _amountOut;
    }

    /// @notice The ```swapTokensForExactTokens``` function receives an exact amount of output tokens for as few input tokens as possible
    /// @dev Must have an allowance on the BUY_TOKEN prior to invocation
    /// @dev Maintains uniV2 interface
    /// @param _amountOut The amount of sell tokens to receive
    /// @param _amountInMax The maximum amount of buy tokens that can be required before the transaction reverts
    /// @param _to Recipient of the output tokens
    /// @param _deadline Unix timestamp after which the transaction will revert
    /// @return _amounts The input token amount and output token amount
    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] calldata, // _path
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory _amounts) {
        // Ensure deadline has not passed
        if (block.timestamp > _deadline) revert Expired();

        // Calculate the amount of buyTokens in & check invariant
        (uint256 _amountIn, , ) = getAmountIn({ _desiredOut: _amountOut });
        if (_amountIn > _amountInMax) revert ExcessiveInputAmount({ minIn: _amountInMax, actualIn: _amountIn });

        // Interactions: Transfer buyTokens to the contract
        IERC20(BUY_TOKEN).safeTransferFrom({ from: msg.sender, to: address(this), value: _amountIn });

        swap({ _buyTokenOut: 0, _sellTokenOut: _amountOut, _to: _to, _callbackData: new bytes(0) });

        // Set return variable
        _amounts = new uint256[](2);
        _amounts[0] = _amountIn;
        _amounts[1] = _amountOut;
    }

    // ==============================================================================
    // Errors
    // ==============================================================================

    /// @notice The ```AuctionAlreadyExited``` error is emitted when a user attempts to exit an auction that has already ended
    error AuctionAlreadyExited();

    /// @notice The ```AuctionExpired``` error is emitted when a user attempts to interact with an auction that has expired
    error AuctionExpired();

    /// @notice The ```LastAuctionStillActive``` error is emitted when a user attempts to start a new auction before the previous one has ended
    error LastAuctionStillActive();

    /// @notice The ```InsufficientOutputAmount``` error is emitted when a user attempts to swap a given amount of buy tokens that would result in an insufficient amount of sell tokens
    /// @param minOut Minimum out that the user expects
    /// @param actualOut Actual amount out that would occur
    error InsufficientOutputAmount(uint256 minOut, uint256 actualOut);

    /// @notice The ```InsufficientInputAmount``` error is emitted when a user attempts to swap an insufficient amount of buy tokens
    /// @param minIn Minimum in that the contract requires
    /// @param actualIn Actual amount in that has been deposited
    error InsufficientInputAmount(uint256 minIn, uint256 actualIn);

    /// @notice The ```ExcessiveInputAmount``` error is emitted when a user attempts to swap an excessive amount of buy tokens for aa given amount of sell tokens
    /// @param minIn Minimum in that the user expects
    /// @param actualIn Actual amount in that would occur
    error ExcessiveInputAmount(uint256 minIn, uint256 actualIn);

    /// @notice The ```InsufficientSellTokensAvailable``` error is emitted when a user attempts to buy more sell tokens than are left in the auction
    error InsufficientSellTokensAvailable();

    /// @notice The ```CannotPurchaseBuyToken``` error is emitted when a user attempts to buy the buyToken using the swap() function
    error ExcessiveBuyTokenOut(uint256 minOut, uint256 actualOut);

    /// @notice The ```Expired``` error is emitted when a user attempts to make a swap after the transaction deadline has passed
    error Expired();

    /// @notice The ```InvalidTokenIn``` error is emitted when a user attempts to use an invalid buy token
    error InvalidTokenIn();

    /// @notice The ```InvalidTokenOut``` error is emitted when a user attempts to use an invalid sell token
    error InvalidTokenOut();

    // ==============================================================================
    // Events
    // ==============================================================================

    /// @dev The ```AuctionExited``` event is emitted when an auction is ended
    /// @param auctionNumber The ID of the auction
    event AuctionExited(uint256 auctionNumber);

    /// @dev The ```Buy``` event is emitted when a swap occurs and has more information than the ```Swap``` event
    /// @param auctionNumber The ID of the auction, and index in the auctions array
    /// @param buyToken The token used to buy the sellToken being auctioned off
    /// @param sellToken The token being auctioned off
    /// @param amountIn Amount of buyToken in
    /// @param amountOut Amount of sellToken out
    /// @param priceLast The execution price of the buy
    /// @param slippagePerSellToken How many buyTokens (per sellToken) were added as slippage
    event Buy(
        uint256 auctionNumber,
        address buyToken,
        address sellToken,
        uint128 amountIn,
        uint128 amountOut,
        uint128 priceLast,
        uint128 slippagePerSellToken
    );

    /// @notice The ```Swap``` event is emitted when a swap occurs
    /// @param sender The address of the sender
    /// @param amount0In The amount of BUY_TOKEN in
    /// @param amount1In The amount of SELL_TOKEN in
    /// @param amount0Out The amount of BUY_TOKEN out
    /// @param amount1Out The amount of SELL_TOKEN out
    /// @param to The address of the recipient
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    /// @dev The ```AuctionStarted``` event is emitted when an auction is started
    /// @param auctionNumber The ID of the auction
    /// @param sellAmount Amount of sellToken being sold
    /// @param priceStart Starting price of the sellToken, in buyToken
    /// @param priceMin Minimum price of the sellToken, in buyToken
    /// @param priceDecay Price decay, per day, using PRECISION
    /// @param priceSlippage Slippage fraction. E.g (0.01 * PRECISION) = 1%
    /// @param expiry Expiration time of the auction
    event AuctionStarted(
        uint256 auctionNumber,
        uint128 sellAmount,
        uint128 priceStart,
        uint128 priceMin,
        uint128 priceDecay,
        uint128 priceSlippage,
        uint32 expiry
    );
}
