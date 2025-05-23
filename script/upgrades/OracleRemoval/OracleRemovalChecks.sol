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

import { IChainlinkRelayerFactory } from "mento-core-2.5.0/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";
import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

import { ISortedOracles } from "../OracleMigration/OracleMigration.sol";
import { OracleMigrationConfig } from "../OracleMigration/Config.sol";

contract OracleRemovalChecks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  OracleMigrationConfig private config;

  ISortedOracles private sortedOracles;

  address private redstoneAdapter;

  function prepare() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");

    config = new OracleMigrationConfig();
    config.load();

    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    redstoneAdapter = contracts.dependency("RedstoneAdapter");
  }

  function run() public {
    prepare();
    console2.log("\n");

    checkSortedOraclesConfig();
    console2.log("✅ All checks passed\n");
  }

  function checkSortedOraclesConfig() internal {
    console2.log("====🔍 Checking if sortedOracles is correctly configured...====");

    address[] memory allFeeds = Arrays.merge(config.feedsToMigrate(), config.additionalRelayersToWhitelist());
    for (uint i = 0; i < allFeeds.length; i++) {
      address identifier = allFeeds[i];
      address[] memory whitelisted = sortedOracles.getOracles(identifier);

      if (config.isRedstonePowered(identifier)) {
        require(whitelisted.length == 1, "❌ Expected exactly 1 oracle to be whitelisted");
        require(whitelisted[0] == redstoneAdapter, "❌ Expected redstone adapter to be whitelisted");
        console2.log("✅ Redstone adapter is whitelisted on feed %s", config.getFeedName(identifier));
      } else {
        require(whitelisted.length == 0, "❌ Expected no oracles to be whitelisted on chainlink powered feed");
        console2.log("✅ No oracles are whitelisted on chainlink powered feed %s", config.getFeedName(identifier));
      }
    }
    console2.log("🤑 All %d feeds were updated correctly\n", allFeeds.length);
  }
}
