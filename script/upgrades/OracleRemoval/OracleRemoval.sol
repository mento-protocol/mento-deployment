// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "celo-foundry/Test.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IChainlinkRelayerFactory } from "mento-core-2.5.0/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";
import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

import { ISortedOracles } from "../OracleMigration/OracleMigration.sol";
import { OracleMigrationConfig } from "../OracleMigration/Config.sol";

contract OracleRemoval is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;
  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  OracleMigrationConfig private config;

  address private redstoneAdapter;
  ISortedOracles private sortedOracles;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  function loadDeployedContracts() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
  }

  function setAddresses() public {
    config = new OracleMigrationConfig();
    config.load();

    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    redstoneAdapter = contracts.dependency("RedstoneAdapter");
  }

  function run() public {
    prepare();

    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "https://github.com/celo-org/governance/blob/main/CGPs/cgp-0184.md", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    address[] memory feedsToMigrate = config.feedsToMigrate();

    // 1. Remove all oracles from the feeds, except for the redstone adapter
    for (uint i = 0; i < feedsToMigrate.length; i++) {
      address identifier = feedsToMigrate[i];
      removeAllOracles(identifier);
    }

    return transactions;
  }

  function removeAllOracles(address rateFeedIdentifier) internal {
    address[] memory oracles = ISortedOracles(sortedOracles).getOracles(rateFeedIdentifier);
    bool isRedstonePowered = config.isRedstonePowered(rateFeedIdentifier);

    if (isRedstonePowered) {
      require(Arrays.contains(oracles, redstoneAdapter), "Redstone adapter not found on redstone powered feed");
    }

    for (uint i = oracles.length - 1; i >= 0; i--) {
      if (oracles[i] != redstoneAdapter) {
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: address(sortedOracles),
            data: abi.encodeWithSelector(ISortedOracles(0).removeOracle.selector, rateFeedIdentifier, oracles[i], i)
          })
        );
      }

      if (i == 0) break;
    }
  }
}
