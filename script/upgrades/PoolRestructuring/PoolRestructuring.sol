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
import { BreakerBox } from "mento-core-2.5.0/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.5.0/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.5.0/oracles/breakers/ValueDeltaBreaker.sol";
import { TradingLimits } from "mento-core-2.5.0/libraries/TradingLimits.sol";
import { IPricingModule } from "mento-core-2.5.0/interfaces/IPricingModule.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

import { Config } from "script/utils/Config.sol";
import { NewPoolsConfig } from "./NewPoolsConfig.sol";

import { CfgHelper } from "script/upgrades/PoolRestructuring/CfgHelper.sol";
import { PoolsCleanupCfg } from "script/upgrades/PoolRestructuring/PoolsCleanupCfg.sol";
import { TradingLimitsCfg } from "script/upgrades/PoolRestructuring/TradingLimitsCfg.sol";
import { ValueDeltaBreakerCfg } from "script/upgrades/PoolRestructuring/ValueDeltaBreakerCfg.sol";

contract PoolRestructuring is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  CfgHelper private cfgHelper;
  PoolsCleanupCfg private poolsCleanupCfg;
  TradingLimitsCfg private tradingLimitsCfg;
  ValueDeltaBreakerCfg private valueDeltaBreakerCfg;

  address private brokerProxy;
  address private biPoolManagerProxy;
  address private breakerBox;
  address private medianDeltaBreaker;
  address private valueDeltaBreaker;

  mapping(address => bytes32) public referenceRateFeedIDToExchangeId;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
    setExchangeIds();
  }

  function loadDeployedContracts() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");
  }

  function setAddresses() public {
    cfgHelper = new CfgHelper();
    cfgHelper.load();

    poolsCleanupCfg = new PoolsCleanupCfg(cfgHelper);
    tradingLimitsCfg = new TradingLimitsCfg(cfgHelper);
    valueDeltaBreakerCfg = new ValueDeltaBreakerCfg();

    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
  }

  function setExchangeIds() public {
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = 0; i < exchangeIds.length; i++) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory currentExchange = biPoolManager.getPoolExchange(exchangeId);
      referenceRateFeedIDToExchangeId[currentExchange.config.referenceRateFeedID] = exchangeId;
    }

    NewPoolsConfig.NewPools memory newPoolsConfig = NewPoolsConfig.get(contracts);
    for (uint i = 0; i < newPoolsConfig.pools.length; i++) {
      referenceRateFeedIDToExchangeId[newPoolsConfig.pools[i].referenceRateFeedID] = getExchangeId(
        newPoolsConfig.pools[i].asset0,
        newPoolsConfig.pools[i].asset1,
        newPoolsConfig.pools[i].isConstantSum
      );
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

    // 4. Create new pools
    createNewPools();

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

      if (!poolsCleanupCfg.shouldBeDeleted(currentExchange)) {
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

      if (poolsCleanupCfg.shouldRecreateWithNewSpread(currentExchange)) {
        creations++;

        IBiPoolManager.PoolExchange memory newExchange = poolsCleanupCfg.getPoolCfgWithNewSpread(currentExchange);
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

    require(
      deletions == poolsCleanupCfg.poolsToDelete().length,
      "❌ Number of deleted pools txs does not match expected"
    );
    require(
      creations == poolsCleanupCfg.spreadOverrides().length,
      "❌ Number of created pools txs does not match expected"
    );
  }

  function updateValueDeltaBreakersThreshold() internal {
    ValueDeltaBreakerCfg.ValueDeltaBreakerOverride[] memory overrides = valueDeltaBreakerCfg
      .valueDeltaBreakerOverrides();

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
    TradingLimitsCfg.TradingLimitsOverride[] memory overrides = tradingLimitsCfg.tradingLimitsOverrides();

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

  function createNewPools() internal {
    NewPoolsConfig.NewPools memory newPoolsConfig = NewPoolsConfig.get(contracts);

    for (uint256 i = 0; i < newPoolsConfig.pools.length; i++) {
      proposal_createExchange(newPoolsConfig.pools[i]);
      proposal_configureTradingLimits(newPoolsConfig.pools[i]);
    }

    for (uint256 i = 0; i < newPoolsConfig.rateFeedsConfig.length; i++) {
      proosal_configureBreakerBox(newPoolsConfig.rateFeedsConfig[i]);
      proposal_configureMedianDeltaBreaker(newPoolsConfig.rateFeedsConfig[i]);
    }
  }

  /**
   * @notice Creates the exchange for the new pool.
   */
  function proposal_createExchange(Config.Pool memory pool) private {
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    IBiPoolManager.PoolExchange memory poolExchange = IBiPoolManager.PoolExchange({
      asset0: pool.asset0,
      asset1: pool.asset1,
      pricingModule: pool.isConstantSum ? constantSum : constantProduct,
      bucket0: 0,
      bucket1: 0,
      lastBucketUpdate: 0,
      config: IBiPoolManager.PoolConfig({
        spread: FixidityLib.wrap(pool.spread.unwrap()),
        referenceRateFeedID: pool.referenceRateFeedID,
        referenceRateResetFrequency: pool.referenceRateResetFrequency,
        minimumReports: pool.minimumReports,
        stablePoolResetSize: pool.stablePoolResetSize
      })
    });

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxy,
        abi.encodeWithSelector(IBiPoolManager(0).createExchange.selector, poolExchange)
      )
    );
  }

  /**
   * @notice Configures the trading limits for the new pool.
   */
  function proposal_configureTradingLimits(Config.Pool memory pool) private {
    bytes32 exchangeId = referenceRateFeedIDToExchangeId[pool.referenceRateFeedID];

    // Set the trading limit for asset0 of the pool
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxy,
        abi.encodeWithSelector(
          Broker(0).configureTradingLimit.selector,
          exchangeId,
          pool.asset0,
          TradingLimits.Config({
            timestep0: pool.asset0limits.timeStep0,
            timestep1: pool.asset0limits.timeStep1,
            limit0: pool.asset0limits.limit0,
            limit1: pool.asset0limits.limit1,
            limitGlobal: pool.asset0limits.limitGlobal,
            flags: Config.tradingLimitConfigToFlag(pool.asset0limits)
          })
        )
      )
    );

    // Set the trading limit for asset1 of the pool
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxy,
        abi.encodeWithSelector(
          Broker(0).configureTradingLimit.selector,
          exchangeId,
          pool.asset1,
          TradingLimits.Config({
            timestep0: pool.asset1limits.timeStep0,
            timestep1: pool.asset1limits.timeStep1,
            limit0: pool.asset1limits.limit0,
            limit1: pool.asset1limits.limit1,
            limitGlobal: pool.asset1limits.limitGlobal,
            flags: Config.tradingLimitConfigToFlag(pool.asset1limits)
          })
        )
      )
    );
  }

  /**
   * @notice Configures the breaker box for the specified rate feed.
   */
  function proosal_configureBreakerBox(Config.RateFeed memory rateFeed) private {
    // Add the new rate feed to breaker box
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBox,
        abi.encodeWithSelector(BreakerBox(0).addRateFeed.selector, rateFeed.rateFeedID)
      )
    );

    // Enable Median Delta Breaker for rate feed
    if (rateFeed.medianDeltaBreaker0.enabled) {
      // Reset the median value for this rateFeed, if we somehow have one set
      if (MedianDeltaBreaker(medianDeltaBreaker).medianRatesEMA(rateFeed.rateFeedID) != 0) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            medianDeltaBreaker,
            abi.encodeWithSelector(MedianDeltaBreaker(0).resetMedianRateEMA.selector, rateFeed.rateFeedID)
          )
        );
      }

      transactions.push(
        ICeloGovernance.Transaction(
          0,
          breakerBox,
          abi.encodeWithSelector(BreakerBox(0).toggleBreaker.selector, medianDeltaBreaker, rateFeed.rateFeedID, true)
        )
      );
    }
  }

  /**
   * @notice This function creates the transactions to configure the Median Delta Breaker.
   */
  function proposal_configureMedianDeltaBreaker(Config.RateFeed memory rateFeed) private {
    // Set the cooldown time
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setCooldownTime.selector,
          Arrays.addresses(rateFeed.rateFeedID),
          Arrays.uints(rateFeed.medianDeltaBreaker0.cooldown)
        )
      )
    );
    // Set the rate change threshold
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setRateChangeThresholds.selector,
          Arrays.addresses(rateFeed.rateFeedID),
          Arrays.uints(rateFeed.medianDeltaBreaker0.threshold.unwrap())
        )
      )
    );

    // Set the smoothing factor
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setSmoothingFactor.selector,
          rateFeed.rateFeedID,
          rateFeed.medianDeltaBreaker0.smoothingFactor
        )
      )
    );
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
