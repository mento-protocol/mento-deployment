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
contract eXOF is IMentoUpgrade, GovernanceScript {
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

  bool public hasChecks = true;

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

    proposal_initializeEXOFToken(config);
    proposal_configureEXOFConstitutionParameters(config.stableTokenXOF);
    proposal_addEXOFToReserve();
    proposal_enableGasPaymentsWithEXOF();

    proposal_createExchanges(config);
    proposal_configureTradingLimits(config);
    proposal_configureBreakerBox(config);
    proposal_configureMedianDeltaBreakers(config);
    proposal_configureValueDeltaBreaker(config);

    return transactions;
  }

  /**
   * @notice Configures the eXOF token
   */
  function proposal_initializeEXOFToken(eXOFConfig.eXOF memory config) private {
    StableTokenXOFProxy _eXOFProxy = StableTokenXOFProxy(eXOFProxy);
    if (_eXOFProxy._getImplementation() == address(0)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          eXOFProxy,
          abi.encodeWithSelector(
            _eXOFProxy._setAndInitializeImplementation.selector,
            contracts.deployed("StableTokenXOF"),
            abi.encodeWithSelector(
              StableTokenXOF(0).initialize.selector,
              config.stableTokenXOF.name,
              config.stableTokenXOF.symbol,
              config.stableTokenXOF.decimals,
              config.stableTokenXOF.registryAddress,
              config.stableTokenXOF.inflationRate,
              config.stableTokenXOF.inflationFactorUpdatePeriod,
              config.stableTokenXOF.initialBalanceAddresses,
              config.stableTokenXOF.initialBalanceValues,
              config.stableTokenXOF.exchangeIdentifier
            )
          )
        )
      );
    } else {
      console.log("Skipping StableTokenXOFProxy is already initialized");
    }
  }

  /**
   * @notice adds eXOF token to the partial and main reserve
   */
  function proposal_addEXOFToReserve() private {
    if (IReserve(partialReserveProxy).isStableAsset(eXOFProxy) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          partialReserveProxy,
          abi.encodeWithSelector(IReserve(0).addToken.selector, eXOFProxy)
        )
      );
    } else {
      console.log("Token already added to the partial reserve, skipping: %s", eXOFProxy);
    }
  }

  /**
   * @notice enable gas payments with XOF
   */
  function proposal_enableGasPaymentsWithEXOF() private {
    address feeCurrencyWhitelistProxy = contracts.celoRegistry("FeeCurrencyWhitelist");
    address[] memory whitelist = IFeeCurrencyWhitelist(feeCurrencyWhitelistProxy).getWhitelist();
    for (uint256 i = 0; i < whitelist.length; i++) {
      if (whitelist[i] == eXOFProxy) {
        console.log("Gas payments with XOF already enabled, skipping");
        return;
      }
    }
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        feeCurrencyWhitelistProxy,
        abi.encodeWithSelector(IFeeCurrencyWhitelist(0).addToken.selector, eXOFProxy)
      )
    );
  }

  /**
   * @notice configure eXOF constitution parameters
   * @dev see cBRl GCP(https://celo.stake.id/#/proposal/49) for reference
   */
  function proposal_configureEXOFConstitutionParameters(Config.StableToken memory stableTokenConfig) private {
    address governanceProxy = contracts.celoRegistry("Governance");

    for (uint256 i = 0; i < stableTokenConfig.constitutionFunctionSelectors.length; i++) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          governanceProxy,
          abi.encodeWithSelector(
            ICeloGovernance(0).setConstitution.selector,
            eXOFProxy,
            stableTokenConfig.constitutionFunctionSelectors[i],
            stableTokenConfig.constitutionThresholds[i]
          )
        )
      );
    }
  }

  /**
   * @notice Creates the exchanges for the new pools.
   */
  function proposal_createExchanges(eXOFConfig.eXOF memory config) private {
    // Get the address of the pricing modules
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    for (uint256 i = 0; i < config.pools.length; i++) {
      Config.Pool memory poolConfig = config.pools[i];
      IBiPoolManager.PoolExchange memory pool = IBiPoolManager.PoolExchange({
        asset0: poolConfig.asset0,
        asset1: poolConfig.asset1,
        pricingModule: poolConfig.isConstantSum ? constantSum : constantProduct,
        bucket0: 0,
        bucket1: 0,
        lastBucketUpdate: 0,
        config: IBiPoolManager.PoolConfig({
          spread: FixidityLib.wrap(poolConfig.spread.unwrap()),
          referenceRateFeedID: poolConfig.referenceRateFeedID,
          referenceRateResetFrequency: poolConfig.referenceRateResetFrequency,
          minimumReports: poolConfig.minimumReports,
          stablePoolResetSize: poolConfig.stablePoolResetSize
        })
      });

      transactions.push(
        ICeloGovernance.Transaction(
          0,
          biPoolManagerProxy,
          abi.encodeWithSelector(IBiPoolManager(0).createExchange.selector, pool)
        )
      );
    }
  }

  /**
   * @notice This function creates the transactions to configure the trading limits.
   */
  function proposal_configureTradingLimits(eXOFConfig.eXOF memory config) private {
    for (uint256 i = 0; i < config.pools.length; i++) {
      Config.Pool memory poolConfig = config.pools[i];

      // Set the trading limit for asset0 of the pool
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          brokerProxy,
          abi.encodeWithSelector(
            Broker(0).configureTradingLimit.selector,
            referenceRateFeedIDToExchangeId[poolConfig.referenceRateFeedID],
            poolConfig.asset0,
            TradingLimits.Config({
              timestep0: poolConfig.asset0limits.timeStep0,
              timestep1: poolConfig.asset0limits.timeStep1,
              limit0: poolConfig.asset0limits.limit0,
              limit1: poolConfig.asset0limits.limit1,
              limitGlobal: poolConfig.asset0limits.limitGlobal,
              flags: Config.tradingLimitConfigToFlag(poolConfig.asset0limits)
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
            referenceRateFeedIDToExchangeId[poolConfig.referenceRateFeedID],
            poolConfig.asset1,
            TradingLimits.Config({
              timestep0: poolConfig.asset1limits.timeStep0,
              timestep1: poolConfig.asset1limits.timeStep1,
              limit0: poolConfig.asset1limits.limit0,
              limit1: poolConfig.asset1limits.limit1,
              limitGlobal: poolConfig.asset1limits.limitGlobal,
              flags: Config.tradingLimitConfigToFlag(poolConfig.asset1limits)
            })
          )
        )
      );
    }
  }

  /**
   * @notice This function creates the transactions to configure the Breakerbox.
   */
  function proposal_configureBreakerBox(eXOFConfig.eXOF memory config) private {
    // Add the new rate feeds to breaker box
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBox,
        abi.encodeWithSelector(
          BreakerBox(0).addRateFeeds.selector,
          Arrays.addresses(config.EURXOF.rateFeedID, config.EUROCXOF.rateFeedID, config.CELOXOF.rateFeedID)
        )
      )
    );

    // Set rate feed dependencies
    for (uint i = 0; i < config.rateFeeds.length; i++) {
      Config.RateFeed memory rateFeed = config.rateFeeds[i];
      if (rateFeed.dependentRateFeeds.length > 0) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            breakerBox,
            abi.encodeWithSelector(
              BreakerBox(0).setRateFeedDependencies.selector,
              rateFeed.rateFeedID,
              rateFeed.dependentRateFeeds
            )
          )
        );
      }
    }

    for (uint i = 0; i < config.rateFeeds.length; i++) {
      Config.RateFeed memory rateFeed = config.rateFeeds[i];

      // Enable Median Delta Breaker for rate feed
      if (rateFeed.medianDeltaBreaker0.enabled) {
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

      // Enable Value Delta Breaker for rate feeds
      if (rateFeed.valueDeltaBreaker0.enabled) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            breakerBox,
            abi.encodeWithSelector(BreakerBox(0).toggleBreaker.selector, valueDeltaBreaker, rateFeed.rateFeedID, true)
          )
        );
      }
    }
  }

  /**
   * @notice This function creates the transactions to configure the Median Delta Breaker.
   */
  function proposal_configureMedianDeltaBreakers(eXOFConfig.eXOF memory config) private {
    // Set the cooldown time
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setCooldownTime.selector,
          Arrays.addresses(config.CELOXOF.rateFeedID),
          Arrays.uints(config.CELOXOF.medianDeltaBreaker0.cooldown)
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
          Arrays.addresses(config.CELOXOF.rateFeedID),
          Arrays.uints(config.CELOXOF.medianDeltaBreaker0.threshold.unwrap())
        )
      )
    );
  }

  /**
   * @notice This function creates the transactions to configure the recoverable Value Delta Breaker .
   */
  function proposal_configureValueDeltaBreaker(eXOFConfig.eXOF memory config) private {
    // Set the cooldown times
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setCooldownTimes.selector,
          Arrays.addresses(config.EURXOF.rateFeedID, config.EUROCXOF.rateFeedID),
          Arrays.uints(config.EURXOF.valueDeltaBreaker0.cooldown, config.EUROCXOF.valueDeltaBreaker0.cooldown)
        )
      )
    );
    // Set the rate change thresholds
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setRateChangeThresholds.selector,
          Arrays.addresses(config.EURXOF.rateFeedID, config.EUROCXOF.rateFeedID),
          Arrays.uints(
            config.EURXOF.valueDeltaBreaker0.threshold.unwrap(),
            config.EUROCXOF.valueDeltaBreaker0.threshold.unwrap()
          )
        )
      )
    );
    // Set the reference values
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setReferenceValues.selector,
          Arrays.addresses(config.EURXOF.rateFeedID, config.EUROCXOF.rateFeedID),
          Arrays.uints(
            config.EURXOF.valueDeltaBreaker0.referenceValue,
            config.EUROCXOF.valueDeltaBreaker0.referenceValue
          )
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
}
