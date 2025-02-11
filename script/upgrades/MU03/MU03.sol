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
import { Proxy } from "mento-core-2.2.0/common/Proxy.sol";
import { IERC20Metadata } from "mento-core-2.2.0/common/interfaces/IERC20Metadata.sol";

import { BiPoolManagerProxy } from "mento-core-2.2.0/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core-2.2.0/proxies/BrokerProxy.sol";
import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { Exchange } from "mento-core-2.2.0/legacy/Exchange.sol";
import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/ValueDeltaBreaker.sol";
import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";
import { Reserve } from "mento-core-2.2.0/swap/Reserve.sol";

import { MU03Config, Config } from "./Config.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/**
 forge script {file} --rpc-url $ALFAJORES_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract MU03 is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  ICeloGovernance.Transaction[] private transactions;

  address private cUSD;
  address private cEUR;
  address private cBRL;
  address private celo;
  address private bridgedUSDC;
  address private bridgedEUROC;
  address private breakerBox;
  address private medianDeltaBreaker;
  address private valueDeltaBreaker;
  address payable private biPoolManagerProxyAddress;
  address private brokerProxyAddress;
  address private sortedOraclesProxy;
  address payable private partialReserveProxy;

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
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    cBRL = contracts.celoRegistry("StableTokenBRL");
    celo = contracts.celoRegistry("GoldToken");
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    bridgedEUROC = contracts.dependency("BridgedEUROC");
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
    biPoolManagerProxyAddress = address(uint160(contracts.deployed("BiPoolManagerProxy")));
    brokerProxyAddress = contracts.deployed("BrokerProxy");
    sortedOraclesProxy = contracts.celoRegistry("SortedOracles");
    partialReserveProxy = address(uint160(contracts.deployed("PartialReserveProxy")));
  }

  /**
   * @dev Setups up various configuration structs.
   *      This function is called by the governance script runner.
   */
  function setUpConfigs() public {
    // Create pool configurations
    MU03Config.MU03 memory config = MU03Config.get(contracts);

    // Set the exchange ID for the reference rate feed
    for (uint i = 0; i < config.pools.length; i++) {
      referenceRateFeedIDToExchangeId[config.pools[i].referenceRateFeedID] = getExchangeId(
        config.pools[i].asset0,
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
      createProposal(_transactions, "https://github.com/celo-org/governance/blob/main/CGPs/cgp-0097.md", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    MU03Config.MU03 memory config = MU03Config.get(contracts);

    proposal_addEUROCToPartialReserve();
    proposal_updateBiPoolManagerImplementation();
    proposal_updateBrokerImplementation();
    proposal_updateSortedOraclesImplementation();
    proposal_updateBreakerBoxReferences();
    proposal_createExchanges(config);
    proposal_configureTradingLimits(config);
    proposal_scaleDownReserveFraction();
    proposal_configureBreakerBox(config);
    proposal_configureMedianDeltaBreaker0(config);
    proposal_configureValueDeltaBreaker0(config);
    proposal_whitelistMissingOracleProvider(config);

    return transactions;
  }

  function proposal_addEUROCToPartialReserve() private {
    // addCollateralAsset will throw if it's already added
    if (Reserve(partialReserveProxy).isCollateralAsset(bridgedEUROC) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          partialReserveProxy,
          abi.encodeWithSelector(Reserve(0).addCollateralAsset.selector, bridgedEUROC)
        )
      );
    }

    // set EUROC daily spending ratio to 100%
    if (
      Reserve(partialReserveProxy).getDailySpendingRatioForCollateralAsset(bridgedEUROC) !=
      FixidityLib.fixed1().unwrap()
    ) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          partialReserveProxy,
          abi.encodeWithSelector(
            Reserve(0).setDailySpendingRatioForCollateralAssets.selector,
            Arrays.addresses(bridgedEUROC),
            Arrays.uints(FixidityLib.fixed1().unwrap())
          )
        )
      );
    }
  }

  function proposal_updateBiPoolManagerImplementation() public {
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxyAddress,
        abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("BiPoolManager"))
      )
    );
  }

  function proposal_updateBrokerImplementation() public {
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxyAddress,
        abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("Broker"))
      )
    );
  }

  function proposal_updateSortedOraclesImplementation() public {
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        sortedOraclesProxy,
        abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("SortedOracles"))
      )
    );
  }

  function proposal_updateBreakerBoxReferences() public {
    // Set new BreakerBox address in BiPoolManager
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxyAddress,
        abi.encodeWithSelector(BiPoolManager(0).setBreakerBox.selector, breakerBox)
      )
    );

    // Set new BreakerBox address in SortedOracles
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        sortedOraclesProxy,
        abi.encodeWithSelector(SortedOracles(0).setBreakerBox.selector, breakerBox)
      )
    );
  }

  /**
   * @notice This function generates the transactions required to create the
   *         BiPoolManager exchanges (cUSD/CELO, cEUR/CELO, cBRL/CELO, cUSD/bridgedUSDC,
   *         cEUR/bridgedUSDC, cBRL/bridgedUSDC)
   */
  function proposal_createExchanges(MU03Config.MU03 memory config) private {
    // Get the address of the pricing modules
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    // Set PricingModules
    bytes32[] memory pricingModuleIdentifiers = Arrays.bytes32s(
      keccak256(abi.encodePacked("ConstantSum")),
      keccak256(abi.encodePacked("ConstantProduct"))
    );
    address[] memory pricingModules = Arrays.addresses(address(constantSum), address(constantProduct));

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxyAddress,
        abi.encodeWithSelector(BiPoolManager(0).setPricingModules.selector, pricingModuleIdentifiers, pricingModules)
      )
    );

    Config.Pool[] memory poolsToCreate = new Config.Pool[](4);
    poolsToCreate[0] = config.cUSDUSDC;
    poolsToCreate[1] = config.cEURUSDC;
    poolsToCreate[2] = config.cBRLUSDC;
    poolsToCreate[3] = config.cEUREUROC;

    bool biPoolManagerInitialized = BiPoolManagerProxy(biPoolManagerProxyAddress)._getImplementation() != address(0);
    if (biPoolManagerInitialized) {
      // Destroy cUSD/brdgedUSDC exchange -> since ConstantSum logic has changed
      bytes32 cUSDUSDCExchangeId = getExchangeId(
        config.cUSDUSDC.asset0,
        config.cUSDUSDC.asset1,
        config.cUSDUSDC.isConstantSum
      );
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          contracts.deployed("BiPoolManagerProxy"),
          //it's ok to hardcode the index here since the transaction would fail if index and identifier don't match
          abi.encodeWithSelector(IBiPoolManager(0).destroyExchange.selector, cUSDUSDCExchangeId, 3)
        )
      );

      for (uint256 i = 0; i < poolsToCreate.length; i++) {
        Config.Pool memory poolConfig = poolsToCreate[i];
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
            biPoolManagerProxyAddress,
            abi.encodeWithSelector(IBiPoolManager(0).createExchange.selector, pool)
          )
        );
      }
    }
  }

  /**
   * @notice This function creates the transactions to configure the trading limits.
   */
  function proposal_configureTradingLimits(MU03Config.MU03 memory config) public {
    for (uint256 i = 0; i < config.pools.length; i++) {
      Config.Pool memory poolConfig = config.pools[i];

      // Set the trading limits for the pool
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          brokerProxyAddress,
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
    }
  }

  /**
   * @notice This function creates the transactions to configure the Mento V1 Exchanges.
   */
  function proposal_scaleDownReserveFraction() public {
    address[] memory exchangesV1 = Arrays.addresses(
      contracts.celoRegistry("Exchange"),
      contracts.celoRegistry("ExchangeBRL"),
      contracts.celoRegistry("ExchangeEUR")
    );
    uint256[] memory reserveFractions = Arrays.uints(2e22, 5e21, 5e21); // current reserve fractions from mainnet

    for (uint i = 0; i < exchangesV1.length; i++) {
      Exchange exchange = Exchange(exchangesV1[i]);
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          exchangesV1[i],
          abi.encodeWithSelector(
            exchange.setReserveFraction.selector,
            FixidityLib.wrap(reserveFractions[i]).divide(FixidityLib.newFixed(2))
          )
        )
      );
    }
  }

  function proposal_configureBreakerBox(MU03Config.MU03 memory config) public {
    // Add the rate feeds to breaker box
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBox,
        abi.encodeWithSelector(
          BreakerBox(0).addRateFeeds.selector,
          Arrays.addresses(
            contracts.celoRegistry("StableToken"),
            contracts.celoRegistry("StableTokenEUR"),
            contracts.celoRegistry("StableTokenBRL"),
            contracts.dependency("USDCUSDRateFeedAddr"),
            contracts.dependency("USDCEURRateFeedAddr"),
            contracts.dependency("USDCBRLRateFeedAddr"),
            contracts.dependency("EUROCEURRateFeedAddr")
          )
        )
      )
    );

    // Add the Median Delta Breaker to the breaker box with the trading mode '3' -> trading halted
    if (!BreakerBox(breakerBox).isBreaker(medianDeltaBreaker)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          breakerBox,
          abi.encodeWithSelector(BreakerBox(0).addBreaker.selector, medianDeltaBreaker, 3)
        )
      );
    }

    // Add the Value Delta Breaker to the breaker box with the trading mode '3' -> trading halted
    if (!BreakerBox(breakerBox).isBreaker(valueDeltaBreaker)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          breakerBox,
          abi.encodeWithSelector(BreakerBox(0).addBreaker.selector, valueDeltaBreaker, 3)
        )
      );
    }

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

    for (uint256 i = 0; i < config.rateFeeds.length; i++) {
      Config.RateFeed memory rateFeed = config.rateFeeds[i];
      // Enable Median Delta Breaker for rate feed
      if (rateFeed.medianDeltaBreaker0.enabled) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            breakerBox,
            abi.encodeWithSelector(
              BreakerBox(0).toggleBreaker.selector,
              contracts.deployed("MedianDeltaBreaker"),
              rateFeed.rateFeedID,
              true
            )
          )
        );
      }

      // Enable Value Delta Breaker for rate feeds
      if (rateFeed.valueDeltaBreaker0.enabled) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            breakerBox,
            abi.encodeWithSelector(
              BreakerBox(0).toggleBreaker.selector,
              contracts.deployed("ValueDeltaBreaker"),
              rateFeed.rateFeedID,
              true
            )
          )
        );
      }
    }
  }

  function proposal_configureMedianDeltaBreaker0(MU03Config.MU03 memory config) public {
    address[] memory rateFeeds = Arrays.addresses(
      config.CELOUSD.rateFeedID,
      config.CELOEUR.rateFeedID,
      config.CELOBRL.rateFeedID,
      config.USDCEUR.rateFeedID,
      config.USDCBRL.rateFeedID
    );

    uint[] memory cooldowns = Arrays.uints(
      config.CELOUSD.medianDeltaBreaker0.cooldown,
      config.CELOEUR.medianDeltaBreaker0.cooldown,
      config.CELOBRL.medianDeltaBreaker0.cooldown,
      config.USDCEUR.medianDeltaBreaker0.cooldown,
      config.USDCBRL.medianDeltaBreaker0.cooldown
    );

    // Set the cooldown times
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(MedianDeltaBreaker(0).setCooldownTime.selector, rateFeeds, cooldowns)
      )
    );

    uint[] memory thresholds = Arrays.uints(
      config.CELOUSD.medianDeltaBreaker0.threshold.unwrap(),
      config.CELOEUR.medianDeltaBreaker0.threshold.unwrap(),
      config.CELOBRL.medianDeltaBreaker0.threshold.unwrap(),
      config.USDCEUR.medianDeltaBreaker0.threshold.unwrap(),
      config.USDCBRL.medianDeltaBreaker0.threshold.unwrap()
    );

    // Set the rate change thresholds
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(MedianDeltaBreaker(0).setRateChangeThresholds.selector, rateFeeds, thresholds)
      )
    );

    // Set smoothing factor for rate feeds
    for (uint i = 0; i < config.rateFeeds.length; i++) {
      Config.MedianDeltaBreaker memory breakerConfig = config.rateFeeds[i].medianDeltaBreaker0;
      if (breakerConfig.enabled && breakerConfig.smoothingFactor != 0)
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            medianDeltaBreaker,
            abi.encodeWithSelector(
              MedianDeltaBreaker(0).setSmoothingFactor.selector,
              config.rateFeeds[i].rateFeedID,
              breakerConfig.smoothingFactor
            )
          )
        );
    }
  }

  function proposal_configureValueDeltaBreaker0(MU03Config.MU03 memory config) public {
    // Set reference value for EUROC/EUR rate feed
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setReferenceValues.selector,
          Arrays.addresses(config.EUROCEUR.rateFeedID),
          Arrays.uints(config.EUROCEUR.valueDeltaBreaker0.referenceValue)
        )
      )
    );

    // Set cooldown time for EUROC/EUR rate feed
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setCooldownTimes.selector,
          Arrays.addresses(config.EUROCEUR.rateFeedID),
          Arrays.uints(config.EUROCEUR.valueDeltaBreaker0.cooldown)
        )
      )
    );

    // Set rate change threshold for EUROC/EUR rate feed
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setRateChangeThresholds.selector,
          Arrays.addresses(config.EUROCEUR.rateFeedID),
          Arrays.uints(config.EUROCEUR.valueDeltaBreaker0.threshold.unwrap())
        )
      )
    );
  }

  function proposal_whitelistMissingOracleProvider(MU03Config.MU03 memory config) public {
    // Add DiWu as oracle provider for the EUROC/EUR rate feed
    address diwuOracleAddress = 0xBD136a625299A0ac5Ca7Ce9220aCA6e08a624e37;
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        sortedOraclesProxy,
        abi.encodeWithSelector(SortedOracles(0).addOracle.selector, config.EUROCEUR.rateFeedID, diwuOracleAddress)
      )
    );
  }

  /**
   * @notice Helper function to get the exchange ID for a pool.
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
