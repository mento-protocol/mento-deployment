// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "celo-foundry/Test.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { Broker } from "mento-core-2.5.0/swap/Broker.sol";
import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";
import { ValueDeltaBreaker } from "mento-core-2.5.0/oracles/breakers/ValueDeltaBreaker.sol";
import { TradingLimits } from "mento-core-2.5.0/libraries/TradingLimits.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

import { PoolRestructuringConfig } from "./Config.sol";

import { Config } from "script/utils/Config.sol";

contract PoolRestructuring is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  PoolRestructuringConfig private config;

  address private brokerProxy;
  address private biPoolManagerProxy;
  address private valueDeltaBreaker;

  mapping(address => bytes32) public referenceRateFeedIDToExchangeId;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
    setReferenceRateFeedIDToExchangeId();
  }

  function loadDeployedContracts() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest");
  }

  function setAddresses() public {
    config = new PoolRestructuringConfig();
    config.load();

    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
  }

  function setReferenceRateFeedIDToExchangeId() public {
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = 0; i < exchangeIds.length; i++) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory currentExchange = biPoolManager.getPoolExchange(exchangeId);

      referenceRateFeedIDToExchangeId[currentExchange.config.referenceRateFeedID] = exchangeId;
      console.log("RateFeed ID %s", currentExchange.config.referenceRateFeedID);
      console.logBytes32(exchangeId);
      console.log("--------------------------------");
    }
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

    // 2. Update the value delta breakers threshold on some pools
    updateValueDeltaBreakersThreshold();

    // 3. Update the trading limits on some pools
    updateTradingLimits();

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

  function updateValueDeltaBreakersThreshold() internal {
    PoolRestructuringConfig.ValueDeltaBreakerOverride[] memory overrides = config.valueDeltaBreakerOverrides();

    for (uint256 i = 0; i < overrides.length; i++) {
      uint256 currentThreshold = ValueDeltaBreaker(valueDeltaBreaker).rateChangeThreshold(overrides[i].rateFeedId);
      require(currentThreshold == overrides[i].currentThreshold, "❌ Current threshold mismatch");
    }

    address[] memory rateFeedIds = Arrays.addresses(overrides[0].rateFeedId, overrides[1].rateFeedId);
    uint256[] memory newThresholds = Arrays.uints(overrides[0].targetThreshold, overrides[1].targetThreshold);

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(ValueDeltaBreaker(0).setRateChangeThresholds.selector, rateFeedIds, newThresholds)
      )
    );
  }

  function updateTradingLimits() internal {
    PoolRestructuringConfig.TradingLimitsOverride[] memory overrides = config.tradingLimitsOverrides();

    for (uint256 i = 0; i < overrides.length; i++) {
      bytes32 exchangeId = referenceRateFeedIDToExchangeId[overrides[i].referenceRateFeedID];
      require(exchangeId != bytes32(0), "❌ Exchange ID not found for trading limits override");

      bytes32 limit0Id = exchangeId ^ bytes32(uint256(uint160(overrides[i].asset0)));

      if (!isSameTradingLimitConfig(limit0Id, overrides[i].asset0Config)) {
        // update the trading limits on asset0 of the pool
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            brokerProxy,
            abi.encodeWithSelector(
              Broker(0).configureTradingLimit.selector,
              exchangeId,
              overrides[i].asset0,
              TradingLimits.Config({
                timestep0: overrides[i].asset0Config.timeStep0,
                timestep1: overrides[i].asset0Config.timeStep1,
                limit0: overrides[i].asset0Config.limit0,
                limit1: overrides[i].asset0Config.limit1,
                limitGlobal: overrides[i].asset0Config.limitGlobal,
                flags: Config.tradingLimitConfigToFlag(overrides[i].asset0Config)
              })
            )
          )
        );
      }

      bytes32 limit1Id = exchangeId ^ bytes32(uint256(uint160(overrides[i].asset1)));

      if (!isSameTradingLimitConfig(limit1Id, overrides[i].asset1Config)) {
        // update trading limits on asset1 of the pool
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            brokerProxy,
            abi.encodeWithSelector(
              Broker(0).configureTradingLimit.selector,
              exchangeId,
              overrides[i].asset1,
              TradingLimits.Config({
                timestep0: overrides[i].asset1Config.timeStep0,
                timestep1: overrides[i].asset1Config.timeStep1,
                limit0: overrides[i].asset1Config.limit0,
                limit1: overrides[i].asset1Config.limit1,
                limitGlobal: overrides[i].asset1Config.limitGlobal,
                flags: Config.tradingLimitConfigToFlag(overrides[i].asset1Config)
              })
            )
          )
        );
      }
    }
  }

  function isSameTradingLimitConfig(
    bytes32 configId,
    Config.TradingLimit memory newConfig
  ) internal view returns (bool) {
    (uint32 timestamp0, uint32 timestamp1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags) = Broker(
      brokerProxy
    ).tradingLimitsConfig(configId);
    if (flags != Config.tradingLimitConfigToFlag(newConfig)) return false;
    if (timestamp0 != newConfig.timeStep0) return false;
    if (timestamp1 != newConfig.timeStep1) return false;
    if (limit0 != newConfig.limit0) return false;
    if (limit1 != newConfig.limit1) return false;
    if (limitGlobal != newConfig.limitGlobal) return false;
    return true;
  }
}
