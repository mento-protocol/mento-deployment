// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "celo-foundry/Test.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

import { PoolRestructuringConfig } from "./Config.sol";

contract PoolRestructuring is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;
  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  PoolRestructuringConfig private config;

  address private biPoolManagerProxy;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  function loadDeployedContracts() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
  }

  function setAddresses() public {
    config = new PoolRestructuringConfig();
    config.load();

    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
  }

  function run() public {
    prepare();

    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "TODO", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    // 1. Delete some pools, and re-create some of them with a newly proposed spread
    deleteAndRecreatePoolsWithNewSpread();

    return transactions;
  }

  function deleteAndRecreatePoolsWithNewSpread() internal {
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    uint256 deletions = 0;
    uint256 creations = 0;
    for (uint256 i = exchangeIds.length - 1; i >= 0; i--) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory currentExchange = biPoolManager.getPoolExchange(exchangeId);

      if (!config.shouldBeDeleted(currentExchange)) {
        continue;
      }

      deletions++;
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          biPoolManagerProxy,
          abi.encodeWithSelector(IBiPoolManager(0).destroyExchange.selector, exchangeId, i)
        )
      );

      if (config.shouldRecreateWithNewSpread(currentExchange)) {
        creations++;

        IBiPoolManager.PoolExchange memory newExchange = config.getPoolCfgWithNewSpread(currentExchange);
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            biPoolManagerProxy,
            abi.encodeWithSelector(IBiPoolManager(0).createExchange.selector, newExchange)
          )
        );
      }

      if (i == 0) break;
    }

    require(deletions == config.poolsToDelete().length, "❌ Number of deleted pools txs does not match expected");
    require(creations == config.spreadOverrides().length, "❌ Number of created pools txs does not match expected");
  }
}
