// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";
import { IPricingModule } from "mento-core-2.2.0/interfaces/IPricingModule.sol";
import { IReserve } from "mento-core-2.2.0/interfaces/IReserve.sol";
import { IRegistry } from "mento-core-2.2.0/common/interfaces/IRegistry.sol";
import { IFeeCurrencyWhitelist } from "../../interfaces/IFeeCurrencyWhitelist.sol";
import { Proxy } from "mento-core-2.2.0/common/Proxy.sol";
import { IERC20Metadata } from "mento-core-2.2.0/common/interfaces/IERC20Metadata.sol";

import { BiPoolManagerProxy } from "mento-core-2.2.0/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core-2.2.0/proxies/BrokerProxy.sol";
import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { Exchange } from "mento-core-2.2.0/legacy/Exchange.sol";
import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/ValueDeltaBreaker.sol";
import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";
import { StableTokenXOF } from "mento-core-2.2.0/legacy/StableTokenXOF.sol";
import { StableTokenXOFProxy } from "mento-core-2.2.0/legacy/proxies/StableTokenXOFProxy.sol";

import { eXOFConfig, Config } from "./Config.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract eXOFRevert is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  ICeloGovernance.Transaction[] private transactions;

  address payable private eXOFProxy;
  address private celo;
  address private bridgedEUROC;
  address private breakerBox;
  address private medianDeltaBreaker;
  address private valueDeltaBreaker;
  address private brokerProxy;
  address private biPoolManagerProxy;
  address private sortedOraclesProxy;
  address private partialReserveProxy;

  // Helper mapping to store the exchange IDs for the reference rate feeds
  mapping(address => bytes32) private referenceRateFeedIDToExchangeId;

  bool public hasChecks = false;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
    setUpConfigs();
  }

  /**
   * @dev Loads the deployed contracts from the previous deployment step
   */
  function loadDeployedContracts() public {
    contracts.load("MU01-00-Create-Proxies", "latest");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU03-02-Create-Implementations", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");
    contracts.load("eXOF-01-Create-Implementations", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // Tokens
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
    celo = contracts.celoRegistry("GoldToken");
    bridgedEUROC = contracts.dependency("BridgedEUROC");

    // Oracles
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
    sortedOraclesProxy = contracts.celoRegistry("SortedOracles");

    // Swaps
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    partialReserveProxy = contracts.deployed("PartialReserveProxy");
  }

  /**
   * @dev Setups up various configuration structs.
   *      This function is called by the governance script runner.
   */
  function setUpConfigs() public {
    // Create pool configurations
    eXOFConfig.eXOF memory config = eXOFConfig.get(contracts);

    // Set the exchange ID for the reference rate feed
    for (uint i = 0; i < config.pools.length; i++) {
      referenceRateFeedIDToExchangeId[config.pools[i].referenceRateFeedID] = getXOFExchangeId(
        config.pools[i].asset1,
        config.pools[i].isConstantSum
      );
    }
  }

  function run() public {
    prepare();
    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "eXOF", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    eXOFConfig.eXOF memory config = eXOFConfig.get(contracts);

    proposal_destroyExchanges(config);
    proposal_revertTradingLimits(config);
    proposal_revertBreakerBox(config);
    proposal_revertMedianDeltaBreakers(config);
    proposal_revertValueDeltaBreaker(config);

    return transactions;
  }

  /**
   * @notice Destroy the exchanges for the new pools.
   */
  function proposal_destroyExchanges(eXOFConfig.eXOF memory config) private {
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = exchangeIds.length - 1; i >= 0; i--) {
      bytes32 exchangeId = exchangeIds[i];
      for (uint256 j = 0; j < config.pools.length; j++) {
        Config.Pool memory poolConfig = config.pools[j];
        if (exchangeId == getExchangeId(poolConfig.asset0, poolConfig.asset1, poolConfig.isConstantSum)) {
          transactions.push(
            ICeloGovernance.Transaction(
              0,
              biPoolManagerProxy,
              abi.encodeWithSelector(IBiPoolManager(0).destroyExchange.selector, exchangeId, i)
            )
          );
        }
      }
      if (i == 0) break;
    }
  }

  /**
   * @notice This function creates the transactions to reset the trading limits.
   */
  function proposal_revertTradingLimits(eXOFConfig.eXOF memory config) private {
    for (uint256 i = 0; i < config.pools.length; i++) {
      Config.Pool memory poolConfig = config.pools[i];

      // Unset the trading limit for asset0 of the pool
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          brokerProxy,
          abi.encodeWithSelector(
            Broker(0).configureTradingLimit.selector,
            referenceRateFeedIDToExchangeId[poolConfig.referenceRateFeedID],
            poolConfig.asset0,
            TradingLimits.Config({ timestep0: 0, timestep1: 0, limit0: 0, limit1: 0, limitGlobal: 0, flags: 0 })
          )
        )
      );

      // Unset the trading limit for asset1 of the pool
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          brokerProxy,
          abi.encodeWithSelector(
            Broker(0).configureTradingLimit.selector,
            referenceRateFeedIDToExchangeId[poolConfig.referenceRateFeedID],
            poolConfig.asset1,
            TradingLimits.Config({ timestep0: 0, timestep1: 0, limit0: 0, limit1: 0, limitGlobal: 0, flags: 0 })
          )
        )
      );
    }
  }

  /**
   * @notice This function creates the transactions to reset the BreakerBox.
   */
  function proposal_revertBreakerBox(eXOFConfig.eXOF memory config) private {
    for (uint i = 0; i < config.rateFeeds.length; i++) {
      Config.RateFeed memory rateFeed = config.rateFeeds[i];
      // Disable Median Delta Breaker for rate feed
      if (rateFeed.medianDeltaBreaker0.enabled) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            breakerBox,
            abi.encodeWithSelector(BreakerBox(0).toggleBreaker.selector, medianDeltaBreaker, rateFeed.rateFeedID, false)
          )
        );
      }

      // Disable Value Delta Breaker for rate feeds
      if (rateFeed.valueDeltaBreaker0.enabled) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            breakerBox,
            abi.encodeWithSelector(BreakerBox(0).toggleBreaker.selector, valueDeltaBreaker, rateFeed.rateFeedID, false)
          )
        );
      }
    }

    // Remove rate feeds from breaker box
    for (uint256 i = 0; i < config.rateFeeds.length; i++) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          breakerBox,
          abi.encodeWithSelector(BreakerBox(0).removeRateFeed.selector, config.rateFeeds[i].rateFeedID)
        )
      );
    }
  }

  /**
   * @notice This function creates the transactions to configure the Median Delta Breaker.
   */
  function proposal_revertMedianDeltaBreakers(eXOFConfig.eXOF memory config) private {
    // Reset the cooldown time
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setCooldownTime.selector,
          Arrays.addresses(config.CELOXOF.rateFeedID),
          Arrays.uints(0)
        )
      )
    );
    // Reset the rate change threshold
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setRateChangeThresholds.selector,
          Arrays.addresses(config.CELOXOF.rateFeedID),
          Arrays.uints(0)
        )
      )
    );

    // Reset the Median Rate EMA
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(MedianDeltaBreaker(0).resetMedianRateEMA.selector, config.CELOXOF.rateFeedID)
      )
    );
  }

  /**
   * @notice This function creates the transactions to revert the Value Delta Breaker configuration.
   */
  function proposal_revertValueDeltaBreaker(eXOFConfig.eXOF memory config) private {
    // Reset the cooldown times
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setCooldownTimes.selector,
          Arrays.addresses(config.EURXOF.rateFeedID, config.EUROCXOF.rateFeedID),
          Arrays.uints(0, 0)
        )
      )
    );
    // Reset the rate change thresholds
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setRateChangeThresholds.selector,
          Arrays.addresses(config.EURXOF.rateFeedID, config.EUROCXOF.rateFeedID),
          Arrays.uints(0, 0)
        )
      )
    );
    // Reset the reference values
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setReferenceValues.selector,
          Arrays.addresses(config.EURXOF.rateFeedID, config.EUROCXOF.rateFeedID),
          Arrays.uints(0, 0)
        )
      )
    );
  }

  /**
   * @notice Helper function to get the exchange ID for a pool.
   */
  function getXOFExchangeId(address asset1, bool isConstantSum) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked("eXOF", IERC20Metadata(asset1).symbol(), isConstantSum ? "ConstantSum" : "ConstantProduct")
      );
  }

  /**
   * @notice Helper function to get the exchange ID for a pool
   */
  function getExchangeId(address asset0, address asset1, bool isConstantSum) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          IERC20Metadata(asset0).symbol(),
          IERC20Metadata(asset1).symbol(),
          isConstantSum ? "ConstantSum" : "ConstantProduct"
        )
      );
  }
}
