// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import { deploySlippageAuctionFactory } from "../script/DeploySlippageAuctionFactory.s.sol";
import { deployFXBFactory } from "../script/DeployFXBFactory.s.sol";
import { DecimalStringHelper } from "src/test/helpers/DecimalStringHelper.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { FXB } from "../contracts/FXB.sol";
import { FXBFactory } from "../contracts/FXBFactory.sol";
import { FXB_LFRAX } from "src/contracts/FXB_LFRAX.sol";
import { IProxyAdmin } from "src/contracts/interfaces/IProxyAdmin.sol";
import { SlippageAuction } from "../contracts/SlippageAuction.sol";
import { SlippageAuctionFactory } from "../contracts/SlippageAuctionFactory.sol";
import { SigUtils } from "./utils/SigUtils.sol";
import { StorageSetterLFRAX } from "src/contracts/utils/StorageSetterLFRAX.sol";
import "../Constants.sol" as Constants;
import { TransparentUpgradeableProxy, ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC20PermitPermissionedOptiMintable } from "src/contracts/interfaces/IERC20PermitPermissionedOptiMintable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Logger } from "frax-std/Logger.sol";

contract BaseTest_FXB_LFRAX is FraxTest, Constants.Helper {
    // Unpriviledged test users
    uint256 internal testerPrivateKey;
    address payable internal tester;
    address payable internal buyer1;
    address payable internal buyer2;

    // SigUtils
    SigUtils public sigUtils_FXB;
    SigUtils public sigUtils_FXB_LFRAX;
    SigUtils public sigUtils_LFRAX;

    // StorageSetterLFRAX
    StorageSetterLFRAX public storageSetterLFRAX = StorageSetterLFRAX(Constants.FraxtalL2.STORAGE_SETTER_LFRAX);

    // frxUSD
    address public frxUSDAddress = 0xFc00000000000000000000000000000000000001;
    IERC20 public frxUSD = IERC20(frxUSDAddress);

    // lFRAX
    address public lFraxAddress = 0xff000000000000000000000000000000000001Fd;
    address public lFraxImpl = 0x17FdBAdAc06C76C73Ea73b834341b02779C36AA0;
    ITransparentUpgradeableProxy public lFraxPxy = ITransparentUpgradeableProxy(lFraxAddress);
    IERC20PermitPermissionedOptiMintable public lFrax = IERC20PermitPermissionedOptiMintable(lFraxAddress);

    // Test tokens
    address public fxs = 0xFc00000000000000000000000000000000000002;
    IERC20 public iFxs = IERC20(fxs);
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IERC20 public iUsdc = IERC20(usdc);

    // FXBFactory
    address public fxbFactoryAddress = 0xaFa1705021f65418e746D8664f4B8A58271f6De4;
    FXBFactory public fxbFactory = FXBFactory(fxbFactoryAddress);

    // FXB
    address public fxb2028Address = Constants.FraxtalL2.FXB20271231; // FXB20271231
    ITransparentUpgradeableProxy public fxb2028Pxy = ITransparentUpgradeableProxy(fxb2028Address);
    FXB public fxb2028 = FXB(fxb2028Address);
    FXB_LFRAX public fxb2028_lfrax_impl;

    // ProxyAdmins
    IProxyAdmin pxyAdminLFrax;
    IProxyAdmin pxyAdminFXB;

    // To prevent stack-too-deep
    // ------------------------------
    string _txJson;
    bytes _theCalldata;
    bytes _theEncodedCall;

    function defaultSetup() internal {
        vm.createSelectFork(vm.envString("FRAXTAL_MAINNET_URL"), 21_213_670);

        console.log("In BaseTest_FXB_LFRAX defaultSetup");

        // Set up test accounts
        // ==========================================
        testerPrivateKey = 0xA11CE;
        tester = payable(vm.addr(testerPrivateKey));
        _mintLFraxTo(tester, 1_000_000e18);
        vm.label(tester, "tester");

        testerPrivateKey = 0xB0b;
        buyer1 = payable(vm.addr(testerPrivateKey));
        _mintLFraxTo(buyer1, 2_000_000e18);
        vm.label(buyer1, "buyer1");

        testerPrivateKey = 0xC4A5E;
        buyer2 = payable(vm.addr(testerPrivateKey));
        _mintLFraxTo(buyer2, 2_000_000e18);
        vm.label(buyer2, "buyer2");

        // Give the safe frxUSD
        // vm.prank(Constants.FraxtalL2.L2_COMPTROLLER_SAFE);
        vm.prank(0x96A394058E2b84A89bac9667B19661Ed003cF5D4);
        frxUSD.transfer(Constants.FraxtalL2.L2_COMPTROLLER_SAFE, 100_000e18);

        // Misc labels
        vm.label(frxUSDAddress, "frxUSD");
        vm.label(lFraxAddress, "lFrax");
        vm.label(lFraxImpl, "lFrax_Impl");
        vm.label(fxbFactoryAddress, "FXBFactory");
    }

    function _doFXBUpgrade() internal {
        console.log("In BaseTest_FXB_LFRAX _doFXBUpgrade");

        // Upgrade the FXB to use LFRAX
        // =====================================
        // Deploy the new impl
        fxb2028_lfrax_impl = new FXB_LFRAX();

        // Find the proxy admin
        // Should be ????
        bytes32 adminSlot = vm.load(fxb2028Address, ERC1967Utils.ADMIN_SLOT);
        pxyAdminFXB = IProxyAdmin(address(uint160(uint256(adminSlot))));
        vm.label(address(pxyAdminFXB), "pxyAdminFXB");
        console.log("Proxy Admin (FXB2028): ", address(pxyAdminFXB));

        // Note the frxUSD in the FXB before the upgrade
        assertGe(IERC20(frxUSDAddress).balanceOf(fxb2028Address), 0, "The FXB should have some frxUSD initially");

        // Upgrade the proxy
        startHoax(Constants.FraxtalL2.L2_COMPTROLLER_SAFE);
        bytes memory data = abi.encodeCall(
            fxb2028_lfrax_impl.initialize,
            ("FXB20271231", lFraxAddress, frxUSDAddress, 1_830_297_600, fxbFactoryAddress)
        );
        pxyAdminFXB.upgradeAndCall(fxb2028Address, address(fxb2028_lfrax_impl), data);
        vm.stopPrank();

        // Make sure the frxUSD got burned
        assertEq(IERC20(frxUSDAddress).balanceOf(fxb2028Address), 0, "The frxUSD in the FXB should have been burned");
    }

    function _doLFRAXUpgrade() internal {
        console.log("In BaseTest_FXB_LFRAX _doLFRAXUpgrade");

        // Upgrade the FXB to use LFRAX
        // =====================================

        // StorageSet the Legacy Frax Dollar (LFRAX) proxy
        // =====================================

        // Find the proxy admin
        // Should be 0xfc00000000000000000000000000000000000009
        bytes32 adminSlot = vm.load(lFraxAddress, ERC1967Utils.ADMIN_SLOT);
        pxyAdminLFrax = IProxyAdmin(address(uint160(uint256(adminSlot))));
        vm.label(address(pxyAdminLFrax), "pxyAdminLFrax");
        console.log("Proxy Admin (LFRAX): ", address(pxyAdminLFrax));

        // // Get the storage set calldata (use this when you are going through Gnosis Safe)
        // _theCalldata = abi.encodeWithSelector(
        //     IProxyAdmin.upgradeAndCall.selector,
        //     payable(lFraxAddress),
        //     address(storageSetterLFRAX),
        //     abi.encodeWithSignature("setNameAndSymbol()")
        // );

        // Upgrade the proxy and storage set the name and symbol
        startHoax(Constants.FraxtalL2.L2_COMPTROLLER_SAFE);
        pxyAdminLFrax.upgradeAndCall(
            lFraxAddress,
            address(storageSetterLFRAX),
            abi.encodeWithSignature("setNameAndSymbol()")
        );
        vm.stopPrank();

        // Set up Legacy Frax Dollar (LFRAX)
        // =====================================

        // Upgrade the proxy
        startHoax(Constants.FraxtalL2.L2_COMPTROLLER_SAFE);
        pxyAdminLFrax.upgrade(lFraxAddress, address(lFraxImpl));
        vm.stopPrank();

        // Mint to test accounts
        // ==========================================
        _mintLFraxTo(tester, 10_000e18);
        _mintLFraxTo(buyer1, 20_000e18);
        _mintLFraxTo(buyer2, 20_000e18);
    }

    function _mintLFraxTo(address to, uint256 _amount) internal returns (uint256 _minted) {
        hoax(Constants.FraxtalL2.L2_STANDARD_BRIDGE);
        _minted = _amount;
        lFrax.mint(to, _minted);
    }
}

//==============================================================================
// Erc20AccountStorageSnapshot Functions
//==============================================================================

struct Erc20AccountStorageSnapshot {
    uint256 balanceOf;
    address _address;
}

function calculateDeltaErc20AccountStorageSnapshot(
    Erc20AccountStorageSnapshot memory _initial,
    Erc20AccountStorageSnapshot memory _final
) pure returns (Erc20AccountStorageSnapshot memory _delta) {
    _delta.balanceOf = stdMath.delta(_initial.balanceOf, _final.balanceOf);
    _delta._address = _initial._address == _final._address ? address(0) : _final._address;
}

//==============================================================================
// Account Storage Snapshot Functions
//==============================================================================

struct AccountStorageSnapshot {
    address account;
    Erc20AccountStorageSnapshot lFraxSnapshot;
    Erc20AccountStorageSnapshot fxbSnapshot;
    uint256 balance;
}

struct DeltaAccountStorageSnapshot {
    AccountStorageSnapshot start;
    AccountStorageSnapshot end;
    AccountStorageSnapshot delta;
}

function accountStorageSnapshot(
    address _account,
    IERC20 _lfrax,
    FXB _fxb
) view returns (AccountStorageSnapshot memory _snapshot) {
    _snapshot.account = _account;
    _snapshot.lFraxSnapshot._address = address(_lfrax);
    _snapshot.lFraxSnapshot.balanceOf = _lfrax.balanceOf(_account);
    _snapshot.fxbSnapshot._address = address(_fxb);
    _snapshot.fxbSnapshot.balanceOf = _fxb.balanceOf(_account);
    _snapshot.balance = _account.balance;
}

function calculateDeltaStorageSnapshot(
    AccountStorageSnapshot memory _initial,
    AccountStorageSnapshot memory _final
) pure returns (AccountStorageSnapshot memory _delta) {
    _delta.account = _initial.account == _final.account ? address(0) : _final.account;
    _delta.lFraxSnapshot.balanceOf = stdMath.delta(_initial.lFraxSnapshot.balanceOf, _final.lFraxSnapshot.balanceOf);
    _delta.fxbSnapshot.balanceOf = stdMath.delta(_initial.fxbSnapshot.balanceOf, _final.fxbSnapshot.balanceOf);
    _delta.balance = stdMath.delta(_initial.balance, _final.balance);
}

function deltaAccountStorageSnapshot(
    AccountStorageSnapshot memory _initial
) view returns (DeltaAccountStorageSnapshot memory _delta) {
    _delta.start = _initial;
    _delta.end = accountStorageSnapshot(
        _initial.account,
        IERC20(_initial.lFraxSnapshot._address),
        FXB(_initial.fxbSnapshot._address)
    );
    _delta.delta = calculateDeltaStorageSnapshot(_delta.start, _delta.end);
}

//==============================================================================
// FxbStorageSnapshot Functions
//==============================================================================

function calculateDeltaBondInfo(
    FXB.BondInfo memory _initial,
    FXB.BondInfo memory _final
) pure returns (FXB.BondInfo memory _delta) {
    _delta.symbol = keccak256(abi.encodePacked(_initial.symbol)) == keccak256(abi.encodePacked(_final.symbol))
        ? ""
        : _final.symbol;
    _delta.name = keccak256(abi.encodePacked(_initial.name)) == keccak256(abi.encodePacked(_final.name))
        ? ""
        : _final.name;
    _delta.maturityTimestamp = stdMath.delta(_initial.maturityTimestamp, _final.maturityTimestamp);
}

struct FxbStorageSnapshot {
    address _address;
    uint256 totalSupply;
    Erc20AccountStorageSnapshot lFraxSnapshot;
    FXB.BondInfo bondInfo;
}

struct DeltaFxbStorageSnapshot {
    FxbStorageSnapshot start;
    FxbStorageSnapshot end;
    FxbStorageSnapshot delta;
}

function fxbStorageSnapshot(FXB _iFxb) view returns (FxbStorageSnapshot memory _snapshot) {
    _snapshot._address = address(_iFxb);
    _snapshot.totalSupply = _iFxb.totalSupply();
    _snapshot.lFraxSnapshot.balanceOf = IERC20(FXB_LFRAX(address(_iFxb)).token()).balanceOf(address(_iFxb));
    _snapshot.bondInfo = _iFxb.bondInfo();
}

function calculateDeltaFxbStorageSnapshot(
    FxbStorageSnapshot memory _initial,
    FxbStorageSnapshot memory _final
) view returns (FxbStorageSnapshot memory _delta) {
    _delta._address = _initial._address == _final._address ? address(0) : _final._address;
    _delta.totalSupply = stdMath.delta(_initial.totalSupply, _final.totalSupply);
    _delta.lFraxSnapshot = calculateDeltaErc20AccountStorageSnapshot(_initial.lFraxSnapshot, _final.lFraxSnapshot);
    _delta.bondInfo = calculateDeltaBondInfo(_initial.bondInfo, _final.bondInfo);
}

function deltaFxbStorageSnapshot(
    FxbStorageSnapshot memory _initial
) view returns (DeltaFxbStorageSnapshot memory _delta) {
    _delta.start = _initial;
    _delta.end = fxbStorageSnapshot(FXB(_initial._address));
    _delta.delta = calculateDeltaFxbStorageSnapshot(_delta.start, _delta.end);
}
