// SPDX-License-Identifier: UNLICENSED
// solhint-disable func-name-mixedcase, contract-name-camelcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 } from "forge-std/Script.sol";
import { FixidityLib } from "mento-core/contracts/common/FixidityLib.sol";

import { ICeloGovernance } from "mento-core/contracts/governance/interfaces/ICeloGovernance.sol";
import { IBiPoolManager } from "mento-core/contracts/interfaces/IBiPoolManager.sol";
import { IPricingModule } from "mento-core/contracts/interfaces/IPricingModule.sol";
import { IReserve } from "mento-core/contracts/interfaces/IReserve.sol";
import { IRegistry } from "mento-core/contracts/common/interfaces/IRegistry.sol";
import { Proxy } from "mento-core/contracts/common/Proxy.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { IBreakerBox } from "mento-core/contracts/interfaces/IBreakerBox.sol";
import { ISortedOracles } from "mento-core/contracts/interfaces/ISortedOracles.sol";
import { IERC20Metadata } from "mento-core/contracts/common/interfaces/IERC20Metadata.sol";

import { BreakerBoxProxy } from "mento-core/contracts/proxies/BreakerBoxProxy.sol";
import { BiPoolManagerProxy } from "mento-core/contracts/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core/contracts/proxies/BrokerProxy.sol";
import { Broker } from "mento-core/contracts/Broker.sol";
import { BiPoolManager } from "mento-core/contracts/BiPoolManager.sol";
import { BreakerBox } from "mento-core/contracts/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core/contracts/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core/contracts/ValueDeltaBreaker.sol";
import { TradingLimits } from "mento-core/contracts/common/TradingLimits.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract MU01_BaklavaCGP is GovernanceScript {
  using TradingLimits for TradingLimits.Config;

  ICeloGovernance.Transaction[] private transactions;

  PoolConfiguration private cUSDCeloConfig;
  PoolConfiguration private cEURCeloConfig;
  PoolConfiguration private cBRLCeloConfig;
  PoolConfiguration private cUSDUSDCConfig;

  address private cUSD;
  address private cEUR;
  address private cBRL;
  address private celo;
  address private USDCet;

  address payable private breakerBoxProxyAddress;
  address private cUSDUSCDRateFeedId = address(uint256(keccak256(abi.encodePacked("USDCUSD"))));

  // Helper mapping to store the exchange IDs for the reference rate feeds
  mapping(address => bytes32) private referenceRateFeedIDToExchangeId;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
    setUpPoolConfigs();
  }

  /**
   * @dev Loads the deployed contracts from the previous deployment step
   */
  function loadDeployedContracts() public {
    contracts.load("MU01-00-Create-Proxies", "1674224277");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "1676477381");
    contracts.load("MU01-02-Create-Implementations", "1674225880");
    contracts.load("MU01-04-Create-MockUSDCet", "1676392537");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    cBRL = contracts.celoRegistry("StableTokenBRL");
    celo = contracts.celoRegistry("GoldToken");
    USDCet = contracts.deployed("MockERC20");

    breakerBoxProxyAddress = contracts.deployed("BreakerBoxProxy");
  }

  /**
   * @dev Sets the various values needed for the configuration of the new pools.
   *      This function is called by the governance script runner.
   */
  function setUpPoolConfigs() public {
    // TODO: -> Finish adding trading limit configuration values to
    //          the pool configs below [Tobi]

    // Create pool configuration for cUSD/CELO pool
    cUSDCeloConfig = PoolConfiguration({
      asset0: cUSD,
      asset1: celo,
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 60 * 5,
      minimumReports: 5,
      stablePoolResetSize: 72e23, // 7200000
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: 3e16, // 0.03
      medianDeltaBreakerCooldown: 30 minutes,
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: 0,
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: cUSD,
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: int48(1e24), // 1000000
      asset0_limit1: int48(5e24), // 5000000
      asset0_limitGlobal: 0,
      asset0_flags: uint8(cUSDCeloConfig.asset0_limit0 | cUSDCeloConfig.asset0_limit1)
    });

    // Set the exchange ID for the reference rate feed
    referenceRateFeedIDToExchangeId[cUSDCeloConfig.referenceRateFeedID] = getExchangeId(
      cUSDCeloConfig.asset0,
      cUSDCeloConfig.asset1,
      cUSDCeloConfig.isConstantSum
    );

    // Create pool configuration for cEUR/CELO pool
    cEURCeloConfig = PoolConfiguration({
      asset0: cEUR,
      asset1: celo,
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10000),
      referenceRateResetFrequency: 60 * 5,
      minimumReports: 5,
      stablePoolResetSize: 18e23,
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: 3e16, // 0.03
      medianDeltaBreakerCooldown: 30 minutes,
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: 0,
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: cEUR,
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: int48(1e24), // 1000000
      asset0_limit1: int48(5e24), // 5000000
      asset0_limitGlobal: 0,
      asset0_flags: uint8(cEURCeloConfig.asset0_limit0 | cEURCeloConfig.asset0_limit1)
    });

    // Set the exchange ID for the reference rate feed
    referenceRateFeedIDToExchangeId[cEURCeloConfig.referenceRateFeedID] = getExchangeId(
      cEURCeloConfig.asset0,
      cEURCeloConfig.asset1,
      cEURCeloConfig.isConstantSum
    );

    // Create pool configuration for cBRL/CELO pool
    cBRLCeloConfig = PoolConfiguration({
      asset0: cBRL,
      asset1: celo,
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10000),
      referenceRateResetFrequency: 60 * 5,
      minimumReports: 5,
      stablePoolResetSize: 3e24,
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: 3e16, // 0.03
      medianDeltaBreakerCooldown: 30 minutes,
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: 0,
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: cBRL,
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: int48(1e24), // 1000000
      asset0_limit1: int48(5e24), // 5000000
      asset0_limitGlobal: 0,
      asset0_flags: uint8(cBRLCeloConfig.asset0_limit0 | cBRLCeloConfig.asset0_limit1)
    });

    // Set the exchange ID for the reference rate feed
    referenceRateFeedIDToExchangeId[cBRLCeloConfig.referenceRateFeedID] = getExchangeId(
      cBRLCeloConfig.asset0,
      cBRLCeloConfig.asset1,
      cBRLCeloConfig.isConstantSum
    );

    // Setup the pool configuration for cUSD/USDC pool
    cUSDUSDCConfig = PoolConfiguration({
      asset0: cUSD,
      asset1: USDCet,
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(2, 10000),
      referenceRateResetFrequency: 60 * 5,
      minimumReports: 5,
      stablePoolResetSize: 1e25, // 10000000
      isMedianDeltaBreakerEnabled: false,
      medianDeltaBreakerThreshold: 0,
      medianDeltaBreakerCooldown: 0,
      isValueDeltaBreakerEnabled: true,
      valueDeltaBreakerThreshold: 5e15, // 0.005
      valueDeltaBreakerReferenceValue: 1e18,
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: address(uint256(keccak256(abi.encodePacked("USDCUSD")))),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: int48(1e25), // 10000000
      asset0_limit1: int48(1e25), // 10000000
      asset0_limitGlobal: 0,
      asset0_flags: uint8(cUSDUSDCConfig.asset0_limit0 | cUSDUSDCConfig.asset0_limit1)
    });

    // Set the exchange ID for the reference rate feed
    referenceRateFeedIDToExchangeId[cUSDUSDCConfig.referenceRateFeedID] = getExchangeId(
      cUSDUSDCConfig.asset0,
      cUSDUSDCConfig.asset1,
      cUSDUSDCConfig.isConstantSum
    );
  }

  function run() public {
    prepare();
    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "MU01", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    //proposal_initializeNewProxies();
    proposal_upgradeContracts();
    proposal_configureReserve();
    proposal_registryUpdates();
    proposal_createExchanges();
    proposal_configureCircuitBreaker();
    proposal_configureTradingLimits();
    // TODO: Set Oracle report targets for new rates
    return transactions;
  }

  function proposal_initializeNewProxies() private {
    address sortedOracles = contracts.celoRegistry("SortedOracles");
    address reserve = contracts.celoRegistry("Reserve");

    BreakerBoxProxy breakerBoxProxy = BreakerBoxProxy(contracts.deployed("BreakerBoxProxy"));
    address breakerBox = contracts.deployed("BreakerBox");
    address[] memory rateFeedIDs = new address[](3);
    rateFeedIDs[0] = contracts.celoRegistry("StableToken");
    rateFeedIDs[1] = contracts.celoRegistry("StableTokenEUR");
    rateFeedIDs[2] = contracts.celoRegistry("StableTokenBRL");

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        address(breakerBoxProxy),
        abi.encodeWithSelector(
          breakerBoxProxy._setAndInitializeImplementation.selector,
          breakerBox,
          abi.encodeWithSelector(BreakerBox(0).initialize.selector, rateFeedIDs, ISortedOracles(sortedOracles))
        )
      )
    );

    BiPoolManagerProxy biPoolManagerProxy = BiPoolManagerProxy(contracts.deployed("BiPoolManagerProxy"));
    address biPoolManager = contracts.deployed("BiPoolManager");

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        address(biPoolManagerProxy),
        abi.encodeWithSelector(
          biPoolManagerProxy._setAndInitializeImplementation.selector,
          biPoolManager,
          abi.encodeWithSelector(
            BiPoolManager(0).initialize.selector,
            contracts.deployed("BrokerProxy"),
            IReserve(reserve),
            ISortedOracles(sortedOracles),
            IBreakerBox(address(breakerBoxProxy))
          )
        )
      )
    );

    BrokerProxy brokerProxy = BrokerProxy(address(contracts.deployed("BrokerProxy")));
    address[] memory exchangeProviders = new address[](1);
    exchangeProviders[0] = address(biPoolManagerProxy);

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        address(brokerProxy),
        abi.encodeWithSelector(
          brokerProxy._setAndInitializeImplementation.selector,
          contracts.deployed("Broker"),
          abi.encodeWithSelector(Broker(0).initialize.selector, exchangeProviders, reserve)
        )
      )
    );
  }

  function proposal_upgradeContracts() private {
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        contracts.celoRegistry("Reserve"),
        abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("Reserve"))
      )
    );

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        contracts.celoRegistry("StableToken"),
        abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("StableToken"))
      )
    );

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        contracts.celoRegistry("StableTokenEUR"),
        abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("StableTokenEUR"))
      )
    );

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        contracts.celoRegistry("StableTokenBRL"),
        abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("StableTokenBRL"))
      )
    );
  }

  function proposal_configureReserve() private {
    address reserveProxy = contracts.celoRegistry("Reserve");
    // if (IReserve(reserveProxy).isExchangeSpender(contracts.deployed("BrokerProxy")) == false) {
    //   transactions.push(
    //     ICeloGovernance.Transaction(
    //       0,
    //       reserveProxy,
    //       abi.encodeWithSelector(IReserve(0).addExchangeSpender.selector, contracts.deployed("BrokerProxy"))
    //     )
    //   );
    // }

    if (IReserve(reserveProxy).isCollateralAsset(contracts.dependency("USDCet")) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(IReserve(0).addCollateralAsset.selector, contracts.dependency("USDCet"))
        )
      );
    }

    if (IReserve(reserveProxy).isCollateralAsset(contracts.celoRegistry("GoldToken")) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(IReserve(0).addCollateralAsset.selector, contracts.celoRegistry("GoldToken"))
        )
      );
    }
  }

  function proposal_registryUpdates() private {
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        REGISTRY_ADDRESS,
        abi.encodeWithSelector(IRegistry(0).setAddressFor.selector, "Broker", contracts.deployed("BrokerProxy"))
      )
    );
  }

  /**
   * @notice This function generates the transactions required to create the
   *         BiPoolManager exchanges (cUSD/CELO, cEUR/CELO, cBRL/CELO, cUSD/USDCet)
   */
  function proposal_createExchanges() private {
    IBiPoolManager.PoolExchange[] memory pools = new IBiPoolManager.PoolExchange[](4);

    // Get the address of the newly deployed CPP pricing module
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    // Add the cUSD/CELO pool
    pools[0] = IBiPoolManager.PoolExchange({
      asset0: cUSDCeloConfig.asset0,
      asset1: cUSDCeloConfig.asset1,
      pricingModule: cUSDCeloConfig.isConstantSum ? constantSum : constantProduct,
      bucket0: 0,
      bucket1: 0,
      lastBucketUpdate: 0,
      config: IBiPoolManager.PoolConfig({
        spread: cUSDCeloConfig.spread,
        referenceRateFeedID: cUSD,
        referenceRateResetFrequency: cUSDCeloConfig.referenceRateResetFrequency,
        minimumReports: cUSDCeloConfig.minimumReports,
        stablePoolResetSize: cUSDCeloConfig.stablePoolResetSize
      })
    });

    // Add the cEUR/CELO pool
    pools[1] = IBiPoolManager.PoolExchange({
      asset0: cEURCeloConfig.asset0,
      asset1: cEURCeloConfig.asset1,
      pricingModule: cEURCeloConfig.isConstantSum ? constantSum : constantProduct,
      bucket0: 0,
      bucket1: 0,
      lastBucketUpdate: 0,
      config: IBiPoolManager.PoolConfig({
        spread: cEURCeloConfig.spread,
        referenceRateFeedID: cEURCeloConfig.referenceRateFeedID,
        referenceRateResetFrequency: cEURCeloConfig.referenceRateResetFrequency,
        minimumReports: cEURCeloConfig.minimumReports,
        stablePoolResetSize: cEURCeloConfig.stablePoolResetSize
      })
    });

    // Add the cBRL/CELO pool
    pools[2] = IBiPoolManager.PoolExchange({
      asset0: cBRLCeloConfig.asset0,
      asset1: cBRLCeloConfig.asset1,
      pricingModule: cBRLCeloConfig.isConstantSum ? constantSum : constantProduct,
      bucket0: 0,
      bucket1: 0,
      lastBucketUpdate: 0,
      config: IBiPoolManager.PoolConfig({
        spread: cBRLCeloConfig.spread,
        referenceRateFeedID: cBRLCeloConfig.referenceRateFeedID,
        referenceRateResetFrequency: cBRLCeloConfig.referenceRateResetFrequency,
        minimumReports: cBRLCeloConfig.minimumReports,
        stablePoolResetSize: cBRLCeloConfig.stablePoolResetSize
      })
    });

    // Add the cUSD/USDCet
    pools[3] = IBiPoolManager.PoolExchange({
      asset0: cUSDUSDCConfig.asset0,
      asset1: cUSDUSDCConfig.asset1,
      pricingModule: cUSDUSDCConfig.isConstantSum ? constantSum : constantProduct,
      bucket0: 0,
      bucket1: 0,
      lastBucketUpdate: 0,
      config: IBiPoolManager.PoolConfig({
        spread: cUSDUSDCConfig.spread,
        referenceRateFeedID: cUSDUSDCConfig.referenceRateFeedID,
        referenceRateResetFrequency: cUSDUSDCConfig.referenceRateResetFrequency,
        minimumReports: cUSDUSDCConfig.minimumReports,
        stablePoolResetSize: cUSDUSDCConfig.stablePoolResetSize
      })
    });

    for (uint256 i = 0; i < pools.length; i++) {
      if (pools[i].asset0 != address(0)) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            contracts.deployed("BiPoolManagerProxy"),
            abi.encodeWithSelector(IBiPoolManager(0).createExchange.selector, pools[i])
          )
        );
      }
    }
  }

  /**
   * @notice This function creates the required transactions to configure
   *         the ϟ circuit breaker ϟ.
   * @dev    Configuration of the circuit breaker requires the following steps:
   *        1. Add all ratefeedIds that should be monitored to the circuit breaker.
   *           [BreakerBox.addRateFeeds || BreakerBox.addRateFeed]
   *
   *        2. Add all breakers that should be used to the circuit breaker.
   *           [BreakerBox.addBreaker || BreakerBox.insertBreaker]
   *
   *        3. Configure each breaker for each rateFeed. Configuration will vary
   *           depending on the type of breaker. Median Delta Breaker only requires
   *           a cooldown and threshold to be set. Value Delta Breaker requires
   *           a cooldown, a threshold and a reference value to be set.
   *           [Breaker.setCooldownTimes && Breaker.setThresholds && ValueBreaker.setReferenceValues]
   *
   *        4. Enable each breaker for each rate feed.
   *           [BreakerBox.toggleBreaker]
   */
  function proposal_configureCircuitBreaker() private {
    address medianDeltaBreakerAddress = contracts.deployed("MedianDeltaBreaker");
    address valueDeltaBreakerAddress = contracts.deployed("ValueDeltaBreaker");

    address[] memory allRateFeedIds = new address[](4);
    allRateFeedIds[0] = cUSD;
    allRateFeedIds[1] = cEUR;
    allRateFeedIds[2] = cBRL;
    allRateFeedIds[3] = cUSDUSCDRateFeedId;

    PoolConfiguration[] memory poolConfigs = new PoolConfiguration[](4);
    poolConfigs[0] = cUSDCeloConfig;
    poolConfigs[1] = cEURCeloConfig;
    poolConfigs[2] = cBRLCeloConfig;
    poolConfigs[3] = cUSDUSDCConfig;

    uint256[] memory referenceValues = new uint256[](1);
    referenceValues[0] = cUSDUSDCConfig.valueDeltaBreakerReferenceValue;

    uint256[] memory valueDeltaCoolDownTimes = new uint256[](1);
    valueDeltaCoolDownTimes[0] = cUSDUSDCConfig.valueDeltaBreakerCooldown;

    /* ================================================================ */
    /* ==== 1. Add rateFeedIds to be monitored to the breaker box ===== */
    /* ================================================================ */

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBoxProxyAddress,
        abi.encodeWithSelector(BreakerBox(0).addRateFeeds.selector, allRateFeedIds)
      )
    );

    /* ================================================================ */
    /* ============== 2. Add breakers to the breaker box ============== */
    /* ================================================================ */

    // Current implementation will stop trading for a rateFeed when trading mode is not == 0.
    // (BreakerBox LN266 & LN290)

    // Add the Median Delta Breaker to the breaker box with the trading mode '1' -> No Trading
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBoxProxyAddress,
        abi.encodeWithSelector(BreakerBox(0).addBreaker.selector, medianDeltaBreakerAddress, 1)
      )
    );

    // Add the Value Delta Breaker to the breaker box with the trading mode '2' -> No Trading
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBoxProxyAddress,
        abi.encodeWithSelector(BreakerBox(0).addBreaker.selector, valueDeltaBreakerAddress, 2)
      )
    );

    /* ================================================================ */
    /* ========= 3. Add rateFeed specific config to breakers ========== */
    /* ================================================================ */

    /****** Median Delta Breaker Configuration *******/

    // rateFeedIDs for which Median Delta Breaker is enabled
    address[] memory medianDeltaRateFeedIds = new address[](3);
    medianDeltaRateFeedIds[0] = cUSD;
    medianDeltaRateFeedIds[1] = cEUR;
    medianDeltaRateFeedIds[2] = cBRL;

    // cooldownTimes for rateFeedIDs with Median Delta Breaker enabled
    uint256[] memory medianDeltaBreakerCooldownTimes = new uint256[](3);
    medianDeltaBreakerCooldownTimes[0] = cUSDCeloConfig.medianDeltaBreakerCooldown;
    medianDeltaBreakerCooldownTimes[1] = cEURCeloConfig.medianDeltaBreakerCooldown;
    medianDeltaBreakerCooldownTimes[2] = cBRLCeloConfig.medianDeltaBreakerCooldown;

    // rateChangeThresholds for rateFeedIDs with Median Delta Breaker enabled
    uint256[] memory medianDeltaBreakerRateChangeThresholds = new uint256[](3);
    medianDeltaBreakerRateChangeThresholds[0] = cUSDCeloConfig.medianDeltaBreakerThreshold;
    medianDeltaBreakerRateChangeThresholds[1] = cEURCeloConfig.medianDeltaBreakerThreshold;
    medianDeltaBreakerRateChangeThresholds[2] = cBRLCeloConfig.medianDeltaBreakerThreshold;

    //TODO: This function name will change to setCooldownTimes for consistency.
    //      Update mento-core to latest &Change once PR has been merged.
    //      https://github.com/mento-protocol/mento-core/pull/148

    // Set the cooldown times
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreakerAddress,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setCooldownTime.selector,
          medianDeltaRateFeedIds,
          medianDeltaBreakerCooldownTimes
        )
      )
    );

    // Set the rate change thresholds
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreakerAddress,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setRateChangeThresholds.selector,
          medianDeltaRateFeedIds,
          medianDeltaBreakerCooldownTimes
        )
      )
    );

    /****** Value Delta Breaker Configuration *******/

    // rateFeedIDs for which Value Delta Breaker is enabled
    address[] memory valueDeltaBreakerRateFeedIds = new address[](1);
    valueDeltaBreakerRateFeedIds[0] = cUSDUSCDRateFeedId;

    // reference values for rateFeedIDs with Value Delta Breaker enabled
    uint256[] memory valueDeltaBreakerReferenceValues = new uint256[](1);
    valueDeltaBreakerReferenceValues[0] = cUSDUSDCConfig.valueDeltaBreakerReferenceValue;

    // cooldownTimes for rateFeedIDs with Value Delta Breaker enabled
    uint256[] memory valueDeltaBreakerCooldownTimes = new uint256[](1);
    valueDeltaBreakerCooldownTimes[0] = cUSDUSDCConfig.valueDeltaBreakerCooldown;

    // thresholds for rateFeedIDs with Value Delta Breaker enabled
    uint256[] memory valueDeltaBreakerThresholds = new uint256[](1);
    valueDeltaBreakerThresholds[0] = cUSDUSDCConfig.valueDeltaBreakerThreshold;

    // Set the reference values for the value delta breaker
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreakerAddress,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setReferenceValues.selector,
          valueDeltaBreakerRateFeedIds,
          valueDeltaBreakerReferenceValues
        )
      )
    );

    // Set the cooldown times for the value delta breaker
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreakerAddress,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setCooldownTimes.selector,
          valueDeltaBreakerRateFeedIds,
          valueDeltaBreakerCooldownTimes
        )
      )
    );

    // Set the thresholds for the value delta breaker
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreakerAddress,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setRateChangeThresholds.selector,
          valueDeltaBreakerRateFeedIds,
          valueDeltaBreakerThresholds
        )
      )
    );

    /* ==========================ϟϟϟϟϟϟϟϟϟϟϟ=========================== */
    /* ============ 4. Enable breakers for each rate feed ============= */
    /* ==========================ϟϟϟϟϟϟϟϟϟϟϟ=========================== */

    // Enable the Median Delta Breaker for the rate feeds
    for (uint256 i = 0; i < poolConfigs.length; i++) {
      if (poolConfigs[i].isMedianDeltaBreakerEnabled) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            breakerBoxProxyAddress,
            abi.encodeWithSelector(
              BreakerBox(0).toggleBreaker.selector,
              contracts.deployed("MedianDeltaBreaker"),
              poolConfigs[i].referenceRateFeedID,
              true
            )
          )
        );
      }
    }

    // Enable Value Delta Breaker for cUSD/USDC rate feed
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBoxProxyAddress,
        abi.encodeWithSelector(BreakerBox(0).toggleBreaker.selector, valueDeltaBreakerAddress, cUSDUSCDRateFeedId, true)
      )
    );
  }

  /**
   * @notice This function creates the transactions to configure the trading limits.
   */
  function proposal_configureTradingLimits() public {
    address brokerProxyAddress = contracts.deployed("BreakerBoxProxy");
    // Set the trading limits for cUSD/Celo pool
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxyAddress,
        abi.encodeWithSelector(
          Broker(0).configureTradingLimit.selector,
          referenceRateFeedIDToExchangeId[cUSDCeloConfig.referenceRateFeedID],
          cUSDCeloConfig.asset0,
          TradingLimits.Config({
            timestep0: cUSDCeloConfig.asset0_timeStep0,
            timestep1: cUSDCeloConfig.asset0_timeStep1,
            limit0: cUSDCeloConfig.asset0_limit0,
            limit1: cUSDCeloConfig.asset0_limit1,
            limitGlobal: cUSDCeloConfig.asset0_limitGlobal,
            flags: cUSDCeloConfig.asset0_flags
          })
        )
      )
    );

    // Set the trading limits for cEUR/Celo pool
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxyAddress,
        abi.encodeWithSelector(
          Broker(0).configureTradingLimit.selector,
          referenceRateFeedIDToExchangeId[cEURCeloConfig.referenceRateFeedID],
          cEURCeloConfig.asset0,
          TradingLimits.Config({
            timestep0: cEURCeloConfig.asset0_timeStep0,
            timestep1: cEURCeloConfig.asset0_timeStep1,
            limit0: cEURCeloConfig.asset0_limit0,
            limit1: cEURCeloConfig.asset0_limit1,
            limitGlobal: cEURCeloConfig.asset0_limitGlobal,
            flags: cEURCeloConfig.asset0_flags
          })
        )
      )
    );

    // Set the trading limits for cBRL/Celo pool
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxyAddress,
        abi.encodeWithSelector(
          Broker(0).configureTradingLimit.selector,
          referenceRateFeedIDToExchangeId[cBRLCeloConfig.referenceRateFeedID],
          cBRLCeloConfig.asset0,
          TradingLimits.Config({
            timestep0: cBRLCeloConfig.asset0_timeStep0,
            timestep1: cBRLCeloConfig.asset0_timeStep1,
            limit0: cBRLCeloConfig.asset0_limit0,
            limit1: cBRLCeloConfig.asset0_limit1,
            limitGlobal: cBRLCeloConfig.asset0_limitGlobal,
            flags: cBRLCeloConfig.asset0_flags
          })
        )
      )
    );

    // Set the trading limits for cUSD/USDC pool
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxyAddress,
        abi.encodeWithSelector(
          Broker(0).configureTradingLimit.selector,
          referenceRateFeedIDToExchangeId[cUSDUSDCConfig.referenceRateFeedID],
          cUSDUSDCConfig.asset0,
          TradingLimits.Config({
            timestep0: cUSDUSDCConfig.asset0_timeStep0,
            timestep1: cUSDUSDCConfig.asset0_timeStep1,
            limit0: cUSDUSDCConfig.asset0_limit0,
            limit1: cUSDUSDCConfig.asset0_limit1,
            limitGlobal: cUSDUSDCConfig.asset0_limitGlobal,
            flags: cUSDUSDCConfig.asset0_flags
          })
        )
      )
    );
  }

  /**
   * @notice Helper function to get the exchange ID for a pool.
   */
  function getExchangeId(
    address asset0,
    address asset1,
    bool isConstantSum
  ) internal view returns (bytes32) {
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
