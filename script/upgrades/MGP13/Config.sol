// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { IBiPoolManager, FixidityLib } from "mento-core-2.6.5/interfaces/IBiPoolManager.sol";

contract MGP13Config is GovernanceScript {
  using Contracts for Contracts.Cache;

  struct SpreadOverride {
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

  address internal biPoolManagerProxy;
  address internal biPoolManagerImpl;
  address internal cUSD;
  address internal nativeUSDC;
  address internal nativeUSDT;
  address internal axlUSDC;

  function load() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MGP13-00-Deploy-BiPoolManager-Implementation", "latest");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    biPoolManagerImpl = contracts.deployed("BiPoolManager");

    cUSD = contracts.celoRegistry("StableToken");
    nativeUSDC = contracts.dependency("NativeUSDC");
    nativeUSDT = contracts.dependency("NativeUSDT");
    axlUSDC = contracts.dependency("BridgedUSDC");
  }

  function spreadOverrides() public view returns (SpreadOverride[] memory) {
    SpreadOverride[] memory overrides = new SpreadOverride[](3);

    // cUSD/USDC
    overrides[0] = SpreadOverride({
      exchangeId: 0xacc988382b66ee5456086643dcfd9a5ca43dd8f428f6ef22503d8b8013bcffd7,
      asset0: cUSD,
      asset1: nativeUSDC,
      currentSpread: FixidityLib.newFixed(0), // 0%
      newSpread: FixidityLib.newFixedFraction(5, 10000) // 0.05%
    });

    // cUSD/axlUSDC
    overrides[1] = SpreadOverride({
      exchangeId: 0x0d739efbfc30f303e8d1976c213b4040850d1af40f174f4169b846f6fd3d2f20,
      asset0: cUSD,
      asset1: axlUSDC,
      currentSpread: FixidityLib.newFixed(0), // 0%
      newSpread: FixidityLib.newFixedFraction(5, 10000) // 0.05%
    });

    // cUSD/USDT
    overrides[2] = SpreadOverride({
      exchangeId: 0x773bcec109cee923b5e04706044fd9d6a5121b1a6a4c059c36fdbe5b845d4e9b,
      asset0: cUSD,
      asset1: nativeUSDT,
      currentSpread: FixidityLib.newFixed(0), // 0%
      newSpread: FixidityLib.newFixedFraction(5, 10000) // 0.05%
    });

    return overrides;
  }

  function getBiPoolManagerProxy() external view returns (address) {
    return biPoolManagerProxy;
  }

  function getBiPoolManagerImpl() external view returns (address) {
    return biPoolManagerImpl;
  }
}
