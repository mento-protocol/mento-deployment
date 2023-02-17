// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
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
import { Arrays } from "script/utils/Arrays.sol";
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
import { SortedOracles } from "mento-core/contracts/SortedOracles.sol";
import { Reserve } from "mento-core/contracts/Reserve.sol";
import { PartialReserveProxy } from "contracts/PartialReserveProxy.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract MU01_BaklavaCGP is GovernanceScript {
  using TradingLimits for TradingLimits.Config;

  ICeloGovernance.Transaction[] private transactions;

  uint8 private constant L0 = 1; // 0b001 Limit0
  uint8 private constant L1 = 2; // 0b010 Limit1
  uint8 private constant LG = 4; // 0b100 LimitGlobal

  PoolConfiguration private cUSDCeloConfig;
  PoolConfiguration private cEURCeloConfig;
  PoolConfiguration private cBRLCeloConfig;
  PoolConfiguration private cUSDUSDCConfig;
  PoolConfiguration[] private poolConfigs;
  PartialReserveConfiguration private partialReserveConfig;

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
    setUpConfigs();
  }

  /**
   * @dev Loads the deployed contracts from the previous deployment step
   */
  function loadDeployedContracts() public {
    contracts.load("MU01-00-Create-Proxies", "1676642018");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "1676642105");
    contracts.load("MU01-02-Create-Implementations", "1676642427");
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
    USDCet = contracts.dependency("USDCet");
    breakerBoxProxyAddress = contracts.deployed("BreakerBoxProxy");
  }

  /**
   * @dev Setups up various configuration structs.
   *      This function is called by the governance script runner.
   */
  function setUpConfigs() public {
    // Create partial reserve configurations
    partialReserveConfig = PartialReserveConfiguration({
      // --- not relevant parameters, copied from Reserve.sol
      tobinTaxStalenessThreshold: 3153600000, // 100 years as current in Reserve.sol
      assetAllocationSymbols: Arrays.bytes32s(
        bytes32("cGLD"),
        bytes32("BTC"),
        bytes32("ETH"),
        bytes32("DAI"),
        bytes32("cMCO2")
      ),
      assetAllocationWeights: Arrays.uints(
        uint256(0.5 * 10**24),
        uint256(0.1 * 10**24),
        uint256(0.1 * 10**24),
        uint256(0.295 * 10**24),
        uint256(0.005 * 10**24)
      ),
      tobinTax: FixidityLib.newFixed(0).unwrap(), // disabled as current Reserve.sol
      tobinTaxReserveRatio: FixidityLib.newFixed(0).unwrap(), // disabled as current Reserve.sol
      frozenGold: 0, // no frozen gold
      frozenDays: 0,  // no frozen gold
      // --- relevant parameters below
      registryAddress: address(0x000000000000000000000000000000000000ce10), // celo registry address
      spendingRatioForCelo: FixidityLib.fixed1().unwrap(), // 100% spending
      collateralAssets: Arrays.addresses(contracts.dependency("USDCet"), contracts.celoRegistry("GoldToken")),
      collateralAssetDailySpendingRatios: Arrays.uints(
        FixidityLib.fixed1().unwrap(), 
        FixidityLib.fixed1().unwrap()
      ) // 100% spending
    });

    // Create pool configuration for cUSD/CELO pool
    cUSDCeloConfig = PoolConfiguration({
      asset0: cUSD,
      asset1: celo,
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 7_200_000 * 1e18, // 7.2mil
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      medianDeltaBreakerCooldown: 30 minutes,
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: FixidityLib.wrap(0),
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: cUSD,
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 1_000_000,
      asset0_limit1: 5_000_000,
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });
    poolConfigs.push(cUSDCeloConfig);

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
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8mil
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      medianDeltaBreakerCooldown: 30 minutes,
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: FixidityLib.wrap(0),
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: cEUR,
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 1_000_000,
      asset0_limit1: 5_000_000,
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });
    poolConfigs.push(cEURCeloConfig);

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
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 3_000_000 * 1e18, // 3min
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      medianDeltaBreakerCooldown: 30 minutes,
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: FixidityLib.wrap(0),
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: cBRL,
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: int48(1_000_000),
      asset0_limit1: int48(5_000_000),
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });
    poolConfigs.push(cBRLCeloConfig);

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
      spread: FixidityLib.newFixedFraction(2, 10000), // 0.0002
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 10_000_000 * 1e18, // 10mil
      isMedianDeltaBreakerEnabled: false,
      medianDeltaBreakerThreshold: FixidityLib.wrap(0),
      medianDeltaBreakerCooldown: 0,
      isValueDeltaBreakerEnabled: true,
      valueDeltaBreakerThreshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      valueDeltaBreakerReferenceValue: 1e18, // 1$
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: contracts.dependency("USDCUSDRateFeedAddr"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 10_000_000,
      asset0_limit1: 10_000_000,
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });
    poolConfigs.push(cUSDUSDCConfig);

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

    proposal_initializeNewProxies();
    proposal_upgradeContracts();
    proposal_configurePartialReserve();
    proposal_registryUpdates();
    proposal_createExchanges();
    proposal_configureCircuitBreaker();
    proposal_configureTradingLimits();

    return transactions;
  }

  function proposal_initializeNewProxies() private {
    address sortedOracles = contracts.celoRegistry("SortedOracles");
    address payable partialReserveProxyAddress = contracts.deployed("PartialReserveProxy");

    BreakerBoxProxy breakerBoxProxy = BreakerBoxProxy(contracts.deployed("BreakerBoxProxy"));
    if (breakerBoxProxy._getImplementation() == address(0)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          address(breakerBoxProxy),
          abi.encodeWithSelector(
            breakerBoxProxy._setAndInitializeImplementation.selector,
            contracts.deployed("BreakerBox"),
            abi.encodeWithSelector(
              BreakerBox(0).initialize.selector,
              Arrays.addresses(
                contracts.celoRegistry("StableToken"),
                contracts.celoRegistry("StableTokenEUR"),
                contracts.celoRegistry("StableTokenBRL"),
                contracts.dependency("USDCUSDRateFeedAddr")
              ),
              ISortedOracles(sortedOracles)
            )
          )
        )
      );
    } else {
      console2.log("Skipping BreakerBoxProxy - already initialized");
    }

    BiPoolManagerProxy biPoolManagerProxy = BiPoolManagerProxy(contracts.deployed("BiPoolManagerProxy"));
    if (biPoolManagerProxy._getImplementation() == address(0)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          address(biPoolManagerProxy),
          abi.encodeWithSelector(
            biPoolManagerProxy._setAndInitializeImplementation.selector,
            contracts.deployed("BiPoolManager"),
            abi.encodeWithSelector(
              BiPoolManager(0).initialize.selector,
              contracts.deployed("BrokerProxy"),
              IReserve(partialReserveProxyAddress),
              ISortedOracles(sortedOracles),
              IBreakerBox(address(breakerBoxProxy))
            )
          )
        )
      );
    } else {
      console2.log("Skipping BiPoolManagerProxy - already initialized");
    }

    BrokerProxy brokerProxy = BrokerProxy(address(contracts.deployed("BrokerProxy")));
    if (brokerProxy._getImplementation() == address(0)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          address(brokerProxy),
          abi.encodeWithSelector(
            brokerProxy._setAndInitializeImplementation.selector,
            contracts.deployed("Broker"),
            abi.encodeWithSelector(
              Broker(0).initialize.selector,
              Arrays.addresses(address(biPoolManagerProxy)),
              partialReserveProxyAddress
            )
          )
        )
      );
    } else {
      console2.log("Skipping BrokerProxy - already initialized");
    }

    PartialReserveProxy partialReserveProxy = PartialReserveProxy(partialReserveProxyAddress);
    if (partialReserveProxy._getImplementation() == address(0)) {
      Reserve reserve = Reserve(contracts.deployed("Reserve"));
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          address(partialReserveProxy),
          abi.encodeWithSelector(
            partialReserveProxy._setAndInitializeImplementation.selector,
            reserve,
            abi.encodeWithSelector(
              Reserve(0).initialize.selector,
              partialReserveConfig.registryAddress,
              partialReserveConfig.tobinTaxStalenessThreshold,
              partialReserveConfig.spendingRatioForCelo,
              partialReserveConfig.frozenGold,
              partialReserveConfig.frozenDays,
              partialReserveConfig.assetAllocationSymbols,
              partialReserveConfig.assetAllocationWeights,
              partialReserveConfig.tobinTax,
              partialReserveConfig.tobinTaxReserveRatio,
              partialReserveConfig.collateralAssets,
              partialReserveConfig.collateralAssetDailySpendingRatios
            )
          )
        )
      );
    } else {
      console2.log("Skipping PartianReserveProxy - already initialized");
    }
  }

  function proposal_upgradeContracts() private {
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

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        contracts.celoRegistry("SortedOracles"),
        abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("SortedOracles"))
      )
    );
  }

  function proposal_configurePartialReserve() private {
    address payable partialReserveProxy = contracts.deployed("PartialReserveProxy");

    // add Broker as Spender to partial Reserve
    // require(
    //   IReserve(partialReserveProxy).isExchangeSpender(contracts.deployed("BrokerProxy")) == false,
    //   "Broker is already a spender"
    // );
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        partialReserveProxy,
        abi.encodeWithSelector(IReserve(0).addExchangeSpender.selector, contracts.deployed("BrokerProxy"))
      )
    );

    // add multisig as Spender to partial Reserve
    // require(
    //   IReserve(partialReserveProxy).isExchangeSpender(contracts.dependency("PartialReserveMultisig")) == false,
    //   "MultiSig is already a spender"
    // );
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        partialReserveProxy,
        abi.encodeWithSelector(IReserve(0).addSpender.selector, contracts.dependency("PartialReserveMultisig"))
      )
    );

    bool reserveNotInitialized = PartialReserveProxy(partialReserveProxy)._getImplementation() == address(0);

    address[] memory stableTokens = Arrays.addresses(
      contracts.celoRegistry("StableToken"),
      contracts.celoRegistry("StableTokenEUR"),
      contracts.celoRegistry("StableTokenBRL")
    );

    for (uint i  = 0; i < stableTokens.length; i++) {
      if (reserveNotInitialized || IReserve(partialReserveProxy).isStableAsset(stableTokens[i]) == false) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            partialReserveProxy,
            abi.encodeWithSelector(IReserve(0).addToken.selector, stableTokens[i])
          )
        );
      } else {
        console2.log("Token already added to the reserve, skipping: %s", stableTokens[i]);
      }
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
    address payable biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    bool biPoolManagerInitialized = BiPoolManagerProxy(biPoolManagerProxy)._getImplementation() != address(0);
    if (biPoolManagerInitialized) {
      bytes32[] memory existingExchangeIds = IBiPoolManager(contracts.deployed("BiPoolManagerProxy")).getExchangeIds();
      if (existingExchangeIds.length > 0) {
        console2.log("Destroying existing exchanges: ", existingExchangeIds.length);
        for (uint256 i = 0; i < existingExchangeIds.length; i++) {
          transactions.push(
            ICeloGovernance.Transaction(
              0,
              contracts.deployed("BiPoolManagerProxy"),
              abi.encodeWithSelector(IBiPoolManager(0).destroyExchange.selector, existingExchangeIds[i], 0)
            )
          );
        }
      }
    }

    // Get the address of the newly deployed pricing modules
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    for (uint256 i = 0; i < poolConfigs.length; i++) {
      PoolConfiguration memory poolConfig = poolConfigs[i];
      IBiPoolManager.PoolExchange memory pool = IBiPoolManager.PoolExchange({
        asset0: poolConfig.asset0,
        asset1: poolConfig.asset1,
        pricingModule: poolConfig.isConstantSum ? constantSum : constantProduct,
        bucket0: 0,
        bucket1: 0,
        lastBucketUpdate: 0,
        config: IBiPoolManager.PoolConfig({
          spread: poolConfig.spread,
          referenceRateFeedID: poolConfig.referenceRateFeedID,
          referenceRateResetFrequency: poolConfig.referenceRateResetFrequency,
          minimumReports: poolConfig.minimumReports,
          stablePoolResetSize: poolConfig.stablePoolResetSize
        })
      });

      transactions.push(
        ICeloGovernance.Transaction(
          0,
          contracts.deployed("BiPoolManagerProxy"),
          abi.encodeWithSelector(IBiPoolManager(0).createExchange.selector, pool)
        )
      );
    }
  }

  /**
   * @notice This function creates the required transactions to configure
   *         the ϟ circuit breaker ϟ.
   * @dev    Configuration of the circuit breaker requires the following steps:
   *        1. Add all breakers that should be used to the circuit breaker.
   *           [BreakerBox.addBreaker || BreakerBox.insertBreaker]
   *
   *        2. Configure each breaker for each rateFeed. Configuration will vary
   *           depending on the type of breaker. Median Delta Breaker only requires
   *           a cooldown and threshold to be set. Value Delta Breaker requires
   *           a cooldown, a threshold and a reference value to be set.
   *           [Breaker.setCooldownTimes && Breaker.setThresholds && ValueBreaker.setReferenceValues]
   *
   *        3. Enable each breaker for each rate feed.
   *           [BreakerBox.toggleBreaker]
   *
   *        4. Add the new breaker box address to sorted oracles.
   */
  function proposal_configureCircuitBreaker() private {
    address medianDeltaBreakerAddress = contracts.deployed("MedianDeltaBreaker");
    address valueDeltaBreakerAddress = contracts.deployed("ValueDeltaBreaker");

    /* ================================================================ */
    /* ============== 1. Add breakers to the breaker box ============== */
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
    /* ========= 2. Add rateFeed specific config to breakers ========== */
    /* ================================================================ */

    /****** Median Delta Breaker Configuration *******/

    // Set the cooldown times
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreakerAddress,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setCooldownTime.selector,
          Arrays.addresses(cUSD, cEUR, cBRL),
          Arrays.uints(
            cUSDCeloConfig.medianDeltaBreakerCooldown,
            cEURCeloConfig.medianDeltaBreakerCooldown,
            cBRLCeloConfig.medianDeltaBreakerCooldown
          )
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
          Arrays.addresses(cUSD, cEUR, cBRL),
          Arrays.uints(
            cUSDCeloConfig.medianDeltaBreakerThreshold.unwrap(),
            cEURCeloConfig.medianDeltaBreakerThreshold.unwrap(),
            cBRLCeloConfig.medianDeltaBreakerThreshold.unwrap()
          )
        )
      )
    );

    /****** Value Delta Breaker Configuration *******/

    // Set the reference values for the value delta breaker
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreakerAddress,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setReferenceValues.selector,
          Arrays.addresses(cUSDUSCDRateFeedId),
          Arrays.uints(cUSDUSDCConfig.valueDeltaBreakerReferenceValue)
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
          Arrays.addresses(cUSDUSCDRateFeedId),
          Arrays.uints(cUSDUSDCConfig.valueDeltaBreakerCooldown)
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
          Arrays.addresses(cUSDUSCDRateFeedId),
          Arrays.uints(cUSDUSDCConfig.valueDeltaBreakerThreshold.unwrap())
        )
      )
    );

    /* ==========================ϟϟϟϟϟϟϟϟϟϟϟ=========================== */
    /* ============ 3. Enable breakers for each rate feed ============= */
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

    /* ================================================================ */
    /* ========= 4. Set breaker box address in sorted oracles ========= */
    /* ================================================================ */

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        contracts.celoRegistry("SortedOracles"),
        abi.encodeWithSelector(SortedOracles(0).setBreakerBox.selector, contracts.deployed("BreakerBoxProxy"))
      )
    );
  }

  /**
   * @notice This function creates the transactions to configure the trading limits.
   */
  function proposal_configureTradingLimits() public {
    address brokerProxyAddress = contracts.deployed("BrokerProxy");
    for (uint256 i = 0; i < poolConfigs.length; i++) {
      PoolConfiguration memory poolConfig = poolConfigs[i];

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
              timestep0: poolConfig.asset0_timeStep0,
              timestep1: poolConfig.asset0_timeStep1,
              limit0: poolConfig.asset0_limit0,
              limit1: poolConfig.asset0_limit1,
              limitGlobal: poolConfig.asset0_limitGlobal,
              flags: poolConfig.asset0_flags
            })
          )
        )
      );
    }
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
