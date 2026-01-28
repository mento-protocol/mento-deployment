// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { Chain as ChainLib } from "script/utils/mento/Chain.sol";

import { IBiPoolManager, FixidityLib } from "mento-core-2.6.5/interfaces/IBiPoolManager.sol";

contract MGP13Config is GovernanceScript {
  using Contracts for Contracts.Cache;

  struct SpreadOverride {
    string name;
    bytes32 exchangeId;
    address asset0;
    address asset1;
    FixidityLib.Fraction currentSpread;
    FixidityLib.Fraction newSpread;
  }

  struct ValueDeltaBreakerThresholdOverride {
    address rateFeedID;
    uint256 currentThreshold;
    uint256 newThreshold;
  }

  address public biPoolManagerProxy;
  address public currentBiPoolManagerImpl;
  address public tmpBiPoolManagerImpl;
  address public cUSD;
  address public nativeUSDC;
  address public nativeUSDT;
  address public axlUSDC;

  function load() public {
    cUSD = cUSDProxy();
    biPoolManagerProxy = _biPoolManagerProxy();
    currentBiPoolManagerImpl = _currentBiPoolManagerImpl();
    tmpBiPoolManagerImpl = _tmpBiPoolManagerImpl();
    nativeUSDC = contracts.dependency("NativeUSDC");
    nativeUSDT = contracts.dependency("NativeUSDT");
    axlUSDC = contracts.dependency("BridgedUSDC");
  }

  function spreadOverrides() public view returns (SpreadOverride[] memory) {
    SpreadOverride[] memory overrides = new SpreadOverride[](3);

    // cUSD/USDC
    overrides[0] = SpreadOverride({
      name: "USDm/USDC",
      exchangeId: 0xacc988382b66ee5456086643dcfd9a5ca43dd8f428f6ef22503d8b8013bcffd7,
      asset0: cUSD,
      asset1: nativeUSDC,
      currentSpread: FixidityLib.newFixed(0), // 0%
      newSpread: FixidityLib.newFixedFraction(5, 10000) // 0.05%
    });

    // cUSD/axlUSDC
    overrides[1] = SpreadOverride({
      name: "USDm/axlUSDC",
      exchangeId: 0x0d739efbfc30f303e8d1976c213b4040850d1af40f174f4169b846f6fd3d2f20,
      asset0: cUSD,
      asset1: axlUSDC,
      currentSpread: FixidityLib.newFixed(0), // 0%
      newSpread: FixidityLib.newFixedFraction(5, 10000) // 0.05%
    });

    // cUSD/USDT
    overrides[2] = SpreadOverride({
      name: "USDm/USDT",
      exchangeId: 0x773bcec109cee923b5e04706044fd9d6a5121b1a6a4c059c36fdbe5b845d4e9b,
      asset0: cUSD,
      asset1: nativeUSDT,
      currentSpread: FixidityLib.newFixed(0), // 0%
      newSpread: FixidityLib.newFixedFraction(5, 10000) // 0.05%
    });

    return overrides;
  }

  function cUSDProxy() internal returns (address) {
    if (ChainLib.isCelo()) {
      return contracts.celoRegistry("StableToken");
    }

    if (ChainLib.isSepolia()) {
      return contracts.dependency("StableTokenUSD");
    }

    revert("unknown network");
  }

  function _biPoolManagerProxy() internal returns (address) {
    if (ChainLib.isCelo()) {
      contracts.loadSilent("MU01-00-Create-Proxies", "latest");
      return contracts.deployed("BiPoolManagerProxy");
    }

    if (ChainLib.isSepolia()) {
      return contracts.dependency("BiPoolManagerProxy");
    }
  }

  function _currentBiPoolManagerImpl() internal returns (address) {
    if (ChainLib.isCelo()) {
      contracts.loadSilent("MU03-02-Create-Implementations", "latest");
      return contracts.deployed("BiPoolManager");
    }

    if (ChainLib.isSepolia()) {
      return contracts.dependency("BiPoolManagerImpl");
    }

    revert("unknown network");
  }

  function _tmpBiPoolManagerImpl() internal returns (address) {
    contracts.loadSilent("MGP13-00-Deploy-BiPoolManager-Implementation", "latest");
    return contracts.deployed("BiPoolManager");
  }
}
