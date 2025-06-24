// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

import { Config } from "script/utils/Config.sol";
import { CfgHelper } from "script/upgrades/PoolRestructuring/CfgHelper.sol";

contract PoolsCleanupCfg is GovernanceScript {
  CfgHelper private cfgHelper;

  struct PoolToDelete {
    address asset0;
    address asset1;
    address rateFeedId;
  }

  struct SpreadOverride {
    address asset0;
    address asset1;
    address rateFeedId;
    FixidityLib.Fraction currentSpread;
    FixidityLib.Fraction targetSpread;
  }

  constructor(CfgHelper _cfgHelper) public {
    cfgHelper = _cfgHelper;
  }

  function poolsToDelete() public view returns (PoolToDelete[] memory) {
    PoolToDelete[] memory pools = new PoolToDelete[](13);

    // non-USD pools that won't be re-created and will be gone for good
    pools[0] = PoolToDelete({
      asset0: cfgHelper.cEURProxy(),
      asset1: cfgHelper.CELOProxy(),
      rateFeedId: cfgHelper.cEURProxy()
    });
    pools[1] = PoolToDelete({
      asset0: cfgHelper.cBRLProxy(),
      asset1: cfgHelper.CELOProxy(),
      rateFeedId: cfgHelper.cBRLProxy()
    });
    pools[2] = PoolToDelete({
      asset0: cfgHelper.cBRLProxy(),
      asset1: cfgHelper.nativeUSDCProxy(),
      rateFeedId: toRateFeedId("USDCBRL")
    });
    pools[3] = PoolToDelete({
      asset0: cfgHelper.cEURProxy(),
      asset1: cfgHelper.axlUSDCProxy(),
      rateFeedId: toRateFeedId("USDCEUR")
    });
    pools[4] = PoolToDelete({
      asset0: cfgHelper.cBRLProxy(),
      asset1: cfgHelper.axlUSDCProxy(),
      rateFeedId: toRateFeedId("USDCBRL")
    });
    pools[5] = PoolToDelete({
      asset0: cfgHelper.eXOFProxy(),
      asset1: cfgHelper.CELOProxy(),
      rateFeedId: cfgHelper.eXOFProxy()
    });
    pools[6] = PoolToDelete({
      asset0: cfgHelper.eXOFProxy(),
      asset1: cfgHelper.axlEUROCProxy(),
      rateFeedId: toRateFeedId("EUROCXOF")
    });
    pools[7] = PoolToDelete({
      asset0: cfgHelper.cEURProxy(),
      asset1: cfgHelper.nativeUSDCProxy(),
      rateFeedId: toRateFeedId("USDCEUR")
    });

    // pools that will be re-created with a new spread, but need to be deleted first
    pools[8] = PoolToDelete({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.nativeUSDCProxy(),
      rateFeedId: toRateFeedId("USDCUSD")
    });
    pools[9] = PoolToDelete({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.nativeUSDTProxy(),
      rateFeedId: toRateFeedId("USDTUSD")
    });
    pools[10] = PoolToDelete({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.axlUSDCProxy(),
      rateFeedId: toRateFeedId("USDCUSD")
    });
    pools[11] = PoolToDelete({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cCADProxy(),
      rateFeedId: toRateFeedId("relayed:CADUSD")
    });
    pools[12] = PoolToDelete({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cAUDProxy(),
      rateFeedId: toRateFeedId("relayed:AUDUSD")
    });

    return pools;
  }

  function spreadOverrides() public view returns (SpreadOverride[] memory) {
    SpreadOverride[] memory overrides = new SpreadOverride[](5);
    // cUSD/nativeUSDC
    overrides[0] = SpreadOverride({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.nativeUSDCProxy(),
      rateFeedId: toRateFeedId("USDCUSD"),
      currentSpread: FixidityLib.newFixedFraction(5, 10000), // 0.05%
      targetSpread: FixidityLib.newFixed(0) // 0%
    });
    // cUSD/USDT
    overrides[1] = SpreadOverride({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.nativeUSDTProxy(),
      rateFeedId: toRateFeedId("USDTUSD"),
      currentSpread: FixidityLib.newFixedFraction(5, 10000), // 0.05%
      targetSpread: FixidityLib.newFixed(0) // 0%
    });
    // cUSD/axlUSDC
    overrides[2] = SpreadOverride({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.axlUSDCProxy(),
      rateFeedId: toRateFeedId("USDCUSD"),
      currentSpread: FixidityLib.newFixedFraction(25, 10000), // 0.25%
      targetSpread: FixidityLib.newFixed(0) // 0%
    });
    // cUSD/cCAD
    overrides[3] = SpreadOverride({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cCADProxy(),
      rateFeedId: toRateFeedId("relayed:CADUSD"),
      currentSpread: FixidityLib.newFixedFraction(3, 1000), // 0.3%
      targetSpread: FixidityLib.newFixedFraction(15, 10000) // 0.15%
    });
    // cUSD/cAUD
    overrides[4] = SpreadOverride({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cAUDProxy(),
      rateFeedId: toRateFeedId("relayed:AUDUSD"),
      currentSpread: FixidityLib.newFixedFraction(3, 1000), // 0.3%
      targetSpread: FixidityLib.newFixedFraction(15, 10000) // 0.15%
    });

    return overrides;
  }

  function shouldBeDeleted(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool) {
    PoolToDelete[] memory pools = poolsToDelete();
    for (uint256 i = 0; i < pools.length; i++) {
      if (pools[i].asset0 == poolCfg.asset0 && pools[i].asset1 == poolCfg.asset1) {
        require(pools[i].rateFeedId == poolCfg.config.referenceRateFeedID, "Rate feed ID mismatch in pool to delete");
        return true;
      }
    }

    return false;
  }

  function shouldRecreateWithNewSpread(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool) {
    SpreadOverride[] memory overrides = spreadOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        return true;
      }
    }

    return false;
  }

  function getPoolCfgWithNewSpread(
    IBiPoolManager.PoolExchange memory currentExchange
  ) public view returns (IBiPoolManager.PoolExchange memory) {
    IBiPoolManager.PoolExchange memory newExchange = currentExchange;
    (FixidityLib.Fraction memory currentSpread, FixidityLib.Fraction memory targetSpread) = getCurrentAndTargetSpread(
      currentExchange
    );
    require(
      FixidityLib.equals(newExchange.config.spread, currentSpread),
      "❌ Current spread mismatch on spread override"
    );

    newExchange.config.spread = targetSpread;
    // Automatically adjusted by the biPoolManager upon creation
    newExchange.bucket0 = 0;
    newExchange.bucket1 = 0;
    newExchange.lastBucketUpdate = 0;

    return newExchange;
  }

  function hasNewSpread(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool) {
    SpreadOverride[] memory overrides = spreadOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        require(
          overrides[i].rateFeedId == poolCfg.config.referenceRateFeedID,
          "Rate feed ID mismatch on spread override"
        );
        return true;
      }
    }

    return false;
  }

  function getCurrentAndTargetSpread(
    IBiPoolManager.PoolExchange memory poolCfg
  ) public view returns (FixidityLib.Fraction memory, FixidityLib.Fraction memory) {
    SpreadOverride[] memory overrides = spreadOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        return (overrides[i].currentSpread, overrides[i].targetSpread);
      }
    }

    require(false, "getCurrentAndTargetSpread() called on a pool with no spread override");
  }
}
