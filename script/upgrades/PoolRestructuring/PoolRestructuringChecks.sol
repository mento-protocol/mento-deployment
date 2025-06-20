// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable var-name-mixedcase, func-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { GovernanceScript } from "script/utils/Script.sol";

import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

import { PoolRestructuringConfig } from "./Config.sol";

contract PoolRestructuringChecks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  PoolRestructuringConfig private config;

  address private biPoolManagerProxy;

  function prepare() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");

    config = new PoolRestructuringConfig();
    config.load();

    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
  }

  function run() public {
    prepare();
    console2.log("\n");

    checkPoolsAreDeletedAndRecreatedWithNewSpread();
    console2.log("✅ All checks passed\n");
  }

  function checkPoolsAreDeletedAndRecreatedWithNewSpread() internal {
    console2.log("====🔍 Checking current pools state... ====");

    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);

    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();
    for (uint256 i = 0; i < exchangeIds.length; i++) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory exchange = biPoolManager.getPoolExchange(exchangeId);

      if (config.shouldBeDeleted(exchange)) {
        // If this pool was supposed to be deleted but it's still there, it means it was part of the ones that
        // had to be re-created with a new spread.
        require(
          config.shouldRecreateWithNewSpread(exchange),
          "❌ Failed to delete pool without a newly proposed spread"
        );

        (, FixidityLib.Fraction memory targetSpread) = config.getCurrentAndTargetSpread(exchange);
        require(FixidityLib.equals(exchange.config.spread, targetSpread), "❌ Re-created pool with wrong spread");

        console2.log("✅ Re-created pool %s with new spread", config.getFeedName(exchange.config.referenceRateFeedID));
      }
    }

    uint256 poolsDeletedButNotRecreated = config.poolsToDelete().length - config.spreadOverrides().length;
    console2.log("✅ Other non-USD pools (%d) were permanently deleted\n", poolsDeletedButNotRecreated);
  }
}
