// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "frax-std/FraxTest.sol";
import { deploySlippageAuctionFactory } from "../script/DeploySlippageAuctionFactory.s.sol";
import { deployFXBFactoryManual } from "../script/DeployFXBFactory.s.sol";
import { FXB } from "../contracts/FXB.sol";
import { FXBFactory } from "../contracts/FXBFactory.sol";
import { SlippageAuction } from "../contracts/SlippageAuction.sol";
import { SlippageAuctionFactory } from "../contracts/SlippageAuctionFactory.sol";
import { SigUtils } from "./utils/SigUtils.sol";
import "../Constants.sol" as Constants;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Logger } from "frax-std/Logger.sol";

contract BaseTest is FraxTest, Constants.Helper {
    // Unpriviledged test users
    uint256 internal testerPrivateKey;
    address payable internal tester;
    address payable internal buyer1;
    address payable internal buyer2;
    address internal owner = Constants.Mainnet.FXB_TIMELOCK;

    address public proxyAdmin = 0x13Fe62cB24aEa5afd179F20D362c056c3881ABcA;
    address public frax = Constants.Mainnet.FRAX_ERC20;
    IERC20 public iFrax = IERC20(frax);

    // Test tokens
    address public fxs = 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;
    IERC20 public iFxs = IERC20(fxs);
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IERC20 public iUsdc = IERC20(usdc);

    // FXBFactory
    FXBFactory public iFxbFactory;
    address public fxbFactory;

    // SlippageAuctionFactory
    SlippageAuctionFactory public iAuctionFactory;
    address public auctionFactory;

    // FXB
    FXB public iFxb;
    address public fxb;

    // SlippageAuction
    SlippageAuction public iAuction;
    address public auction;
    uint128 public amountListed = 1000e18;
    uint128 public priceStart = 0.95e18;
    uint128 public priceMin = 0.9e18;
    uint64 public priceDecay = 1 gwei;
    uint64 public priceSlippage = priceDecay / 100_000;
    uint32 public expiry;

    function defaultSetup() internal {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_105_462);

        // Deploy the contracts
        // ======================

        // FXBFactory
        (iFxbFactory, fxbFactory) = deployFXBFactoryManual({ _owner: owner, _proxyAdmin: proxyAdmin, _token: frax });

        // Auction Factory
        (iAuctionFactory, auctionFactory) = deploySlippageAuctionFactory();

        // Set up test accounts
        testerPrivateKey = 0xA11CE;
        tester = payable(vm.addr(testerPrivateKey));
        _mintFraxTo(tester, 1_000_000e18);
        vm.label(tester, "tester");

        testerPrivateKey = 0xB0b;
        buyer1 = payable(vm.addr(testerPrivateKey));
        _mintFraxTo(buyer1, 2_000_000e18);
        vm.label(buyer1, "buyer1");

        testerPrivateKey = 0xC4A5E;
        buyer2 = payable(vm.addr(testerPrivateKey));
        _mintFraxTo(buyer2, 2_000_000e18);
        vm.label(buyer2, "buyer2");

        // GIVEN: expiry
        expiry = uint32(block.timestamp + 30 days);
    }

    function _mintFraxTo(address to, uint256 _amount) internal returns (uint256 _minted) {
        hoax(Constants.Mainnet.FRAX_ERC20_OWNER);
        _minted = _amount;
        IERC20(Constants.Mainnet.FRAX_ERC20).transfer(to, _minted);
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
    Erc20AccountStorageSnapshot fraxSnapshot;
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
    IERC20 _frax,
    FXB _fxb
) view returns (AccountStorageSnapshot memory _snapshot) {
    _snapshot.account = _account;
    _snapshot.fraxSnapshot._address = address(_frax);
    _snapshot.fraxSnapshot.balanceOf = _frax.balanceOf(_account);
    _snapshot.fxbSnapshot._address = address(_fxb);
    _snapshot.fxbSnapshot.balanceOf = _fxb.balanceOf(_account);
    _snapshot.balance = _account.balance;
}

function calculateDeltaStorageSnapshot(
    AccountStorageSnapshot memory _initial,
    AccountStorageSnapshot memory _final
) pure returns (AccountStorageSnapshot memory _delta) {
    _delta.account = _initial.account == _final.account ? address(0) : _final.account;
    _delta.fraxSnapshot.balanceOf = stdMath.delta(_initial.fraxSnapshot.balanceOf, _final.fraxSnapshot.balanceOf);
    _delta.fxbSnapshot.balanceOf = stdMath.delta(_initial.fxbSnapshot.balanceOf, _final.fxbSnapshot.balanceOf);
    _delta.balance = stdMath.delta(_initial.balance, _final.balance);
}

function deltaAccountStorageSnapshot(
    AccountStorageSnapshot memory _initial
) view returns (DeltaAccountStorageSnapshot memory _delta) {
    _delta.start = _initial;
    _delta.end = accountStorageSnapshot(
        _initial.account,
        IERC20(_initial.fraxSnapshot._address),
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
    Erc20AccountStorageSnapshot fraxSnapshot;
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
    _snapshot.fraxSnapshot.balanceOf = IERC20(address(_iFxb.FRAX())).balanceOf(address(_iFxb));
    _snapshot.bondInfo = _iFxb.bondInfo();
}

function calculateDeltaFxbStorageSnapshot(
    FxbStorageSnapshot memory _initial,
    FxbStorageSnapshot memory _final
) pure returns (FxbStorageSnapshot memory _delta) {
    _delta._address = _initial._address == _final._address ? address(0) : _final._address;
    _delta.totalSupply = stdMath.delta(_initial.totalSupply, _final.totalSupply);
    _delta.fraxSnapshot = calculateDeltaErc20AccountStorageSnapshot(_initial.fraxSnapshot, _final.fraxSnapshot);
    _delta.bondInfo = calculateDeltaBondInfo(_initial.bondInfo, _final.bondInfo);
}

function deltaFxbStorageSnapshot(
    FxbStorageSnapshot memory _initial
) view returns (DeltaFxbStorageSnapshot memory _delta) {
    _delta.start = _initial;
    _delta.end = fxbStorageSnapshot(FXB(_initial._address));
    _delta.delta = calculateDeltaFxbStorageSnapshot(_delta.start, _delta.end);
}

//==============================================================================
// SlippageAuction Functions
//==============================================================================

function calculateDeltaAuction(
    SlippageAuction.Detail memory _initial,
    SlippageAuction.Detail memory _final
) pure returns (SlippageAuction.Detail memory _delta) {
    _delta.amountListed = uint128(stdMath.delta(uint256(_initial.amountListed), uint256(_final.amountListed)));
    _delta.amountLeft = uint128(stdMath.delta(uint256(_initial.amountLeft), uint256(_final.amountLeft)));
    _delta.amountExcessBuy = uint128(stdMath.delta(uint256(_initial.amountExcessBuy), uint256(_final.amountExcessBuy)));
    _delta.amountExcessSell = uint128(
        stdMath.delta(uint256(_initial.amountExcessSell), uint256(_final.amountExcessSell))
    );
    _delta.tokenBuyReceived = uint128(
        stdMath.delta(uint256(_initial.tokenBuyReceived), uint256(_final.tokenBuyReceived))
    );
    _delta.priceLast = uint128(stdMath.delta(uint256(_initial.priceLast), uint256(_final.priceLast)));
    _delta.priceMin = uint128(stdMath.delta(uint256(_initial.priceMin), uint256(_final.priceMin)));
    _delta.priceDecay = uint64(stdMath.delta(uint256(_initial.priceDecay), uint256(_final.priceDecay)));
    _delta.priceSlippage = uint64(stdMath.delta(uint256(_initial.priceSlippage), uint256(_final.priceSlippage)));
    _delta.lastBuyTime = uint32(stdMath.delta(uint256(_initial.lastBuyTime), uint256(_final.lastBuyTime)));
    _delta.expiry = uint32(stdMath.delta(uint256(_initial.expiry), uint256(_final.expiry)));
    _delta.active = _initial.active == _final.active ? false : true;
}

struct SlippageAuctionStorageSnapshot {
    address auction;
    string name;
    uint256 detailsLength;
    SlippageAuction.Detail latestAuction;
    Erc20AccountStorageSnapshot fraxSnapshot;
    Erc20AccountStorageSnapshot fxbSnapshot;
}

struct DeltaSlippageAuctionStorageSnapshot {
    SlippageAuctionStorageSnapshot start;
    SlippageAuctionStorageSnapshot end;
    SlippageAuctionStorageSnapshot delta;
}

function slippageAuctionStorageSnapshot(
    SlippageAuction _iAuction
) view returns (SlippageAuctionStorageSnapshot memory _snapshot) {
    _snapshot.auction = address(_iAuction);
    _snapshot.name = _iAuction.name();
    _snapshot.detailsLength = _iAuction.detailsLength();
    _snapshot.latestAuction = _iAuction.getLatestAuction();
    _snapshot.fraxSnapshot._address = _iAuction.TOKEN_BUY();
    _snapshot.fraxSnapshot.balanceOf = IERC20(_snapshot.fraxSnapshot._address).balanceOf(address(_iAuction));
    _snapshot.fxbSnapshot._address = _iAuction.TOKEN_SELL();
    _snapshot.fxbSnapshot.balanceOf = IERC20(_snapshot.fxbSnapshot._address).balanceOf(address(_iAuction));
}

function calculateDeltaSlippageAuctionStorageSnapshot(
    SlippageAuctionStorageSnapshot memory _initial,
    SlippageAuctionStorageSnapshot memory _final
) pure returns (SlippageAuctionStorageSnapshot memory _delta) {
    _delta.auction = _initial.auction == _final.auction ? address(0) : _final.auction;
    _delta.name = keccak256(abi.encodePacked(_initial.name)) == keccak256(abi.encodePacked(_final.name))
        ? ""
        : _final.name;
    _delta.detailsLength = stdMath.delta(_initial.detailsLength, _final.detailsLength);
    _delta.latestAuction = calculateDeltaAuction(_initial.latestAuction, _final.latestAuction);
    _delta.fraxSnapshot = calculateDeltaErc20AccountStorageSnapshot(_initial.fraxSnapshot, _final.fraxSnapshot);
    _delta.fxbSnapshot = calculateDeltaErc20AccountStorageSnapshot(_initial.fxbSnapshot, _final.fxbSnapshot);
}

function deltaSlippageAuctionStorageSnapshot(
    SlippageAuctionStorageSnapshot memory _initial
) view returns (DeltaSlippageAuctionStorageSnapshot memory _delta) {
    _delta.start = _initial;
    _delta.end = slippageAuctionStorageSnapshot(SlippageAuction(_initial.auction));
    _delta.delta = calculateDeltaSlippageAuctionStorageSnapshot(_delta.start, _delta.end);
}
