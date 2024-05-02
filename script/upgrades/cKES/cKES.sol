// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { FixidityLib } from "mento-core-2.4.0/common/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.4.0/interfaces/IBiPoolManager.sol";
import { IPricingModule } from "mento-core-2.4.0/interfaces/IPricingModule.sol";
import { IReserve } from "mento-core-2.4.0/interfaces/IReserve.sol";
import { IRegistry } from "mento-core-2.4.0/common/interfaces/IRegistry.sol";
import { IFeeCurrencyWhitelist } from "../../interfaces/IFeeCurrencyWhitelist.sol";
import { Proxy } from "mento-core-2.4.0/common/Proxy.sol";
import { IERC20Metadata } from "mento-core-2.4.0/common/interfaces/IERC20Metadata.sol";
import { IStableTokenV2 } from "mento-core-2.4.0/interfaces/IStableTokenV2.sol";

import { BiPoolManagerProxy } from "mento-core-2.4.0/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core-2.4.0/proxies/BrokerProxy.sol";
import { Broker } from "mento-core-2.4.0/swap/Broker.sol";
import { Exchange } from "mento-core-2.4.0/legacy/Exchange.sol";
import { TradingLimits } from "mento-core-2.4.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.4.0/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.4.0/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.4.0/oracles/breakers/ValueDeltaBreaker.sol";
import { StableTokenKESProxy } from "mento-core-2.4.0/legacy/proxies/StableTokenKESProxy.sol";

import { cKESConfig, Config } from "./Config.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract cKES is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  ICeloGovernance.Transaction[] private transactions;

  address payable private stableTokenKESProxy;
  address private stableTokenProxy;

  address private breakerBox;
  address private medianDeltaBreaker;
  address private brokerProxy;
  address private biPoolManagerProxy;
  address private reserveProxy;

  bytes32 private constant POOL_EXCHANGE_ID = keccak256(abi.encodePacked("cKES", "cUSD", "ConstantProduct"));

  bool public hasChecks = true;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  /**
   * @dev Loads the deployed contracts from previous deployments
   */
  function loadDeployedContracts() public {
    contracts.load("MU01-00-Create-Proxies", "latest"); // BrokerProxy & BiPoolProxy
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts", "latest"); // Latest BreakerBox and MedianDeltaBreaker
    contracts.load("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // Tokens
    stableTokenKESProxy = contracts.deployed("StableTokenKESProxy");
    stableTokenProxy = contracts.celoRegistry("StableToken");

    // Oracles
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");

    // Swaps
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    reserveProxy = contracts.celoRegistry("Reserve");
  }

  function run() public {
    prepare();

    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      //TODO: Add link to CGP MD once it's created
      createProposal(_transactions, "SET ME PLS :(", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    cKESConfig.cKES memory config = cKESConfig.get(contracts);

    proposal_initializeCKESToken(config);
    proposal_configureCKESConstitutionParameters();
    proposal_addCKESToReserve();

    //TODO: Confirm we actuallyu want to do this
    proposal_enableGasPaymentsWithCKES();

    proposal_createExchange(config);
    proposal_configureTradingLimits(config);
    proposal_configureBreakerBox(config);
    proposal_configureMedianDeltaBreaker(config);

    return transactions;
  }

  /**
   * @notice Configures the cKES token
   */
  function proposal_initializeCKESToken(cKESConfig.cKES memory config) private {
    StableTokenKESProxy _cKESProxy = StableTokenKESProxy(stableTokenKESProxy);
    if (_cKESProxy._getImplementation() == address(0)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          stableTokenKESProxy,
          abi.encodeWithSelector(
            _cKESProxy._setAndInitializeImplementation.selector,
            contracts.deployed("StableTokenV2"),
            abi.encodeWithSelector(
              IStableTokenV2(0).initialize.selector,
              config.stableTokenConfig.name,
              config.stableTokenConfig.symbol,
              0,
              address(0),
              0,
              0,
              new address[](0),
              new uint256[](0),
              ""
            )
          )
        )
      );

      transactions.push(
        ICeloGovernance.Transaction(
          0,
          stableTokenKESProxy,
          abi.encodeWithSelector(
            _cKESProxy._setAndInitializeImplementation.selector,
            contracts.deployed("StableTokenV2"),
            abi.encodeWithSelector(
              IStableTokenV2(0).initializeV2.selector,
              brokerProxy,
              address(0), // Validators address TODO: Do we need to set this
              address(0) // Exchange address (not used)
            )
          )
        )
      );
    } else {
      console.log("StableTokenKESProxy is already initialized, skipping initialization.");
    }
  }

  /**
   * @notice configure cKES constitution parameters
   * @dev see cBRl GCP(https://celo.stake.id/#/proposal/49) for reference
   */
  function proposal_configureCKESConstitutionParameters() private {
    address governanceProxy = contracts.celoRegistry("Governance");

    bytes4[] memory constitutionFunctionSelectors = Config.getCeloStableConstitutionSelectors();
    uint256[] memory constitutionThresholds = Config.getCeloStableConstitutionThresholds();

    for (uint256 i = 0; i < constitutionFunctionSelectors.length; i++) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          governanceProxy,
          abi.encodeWithSelector(
            ICeloGovernance(0).setConstitution.selector,
            stableTokenKESProxy,
            constitutionFunctionSelectors[i],
            constitutionThresholds[i]
          )
        )
      );
    }
  }

  /**
   * @notice adds cKES token to the main reserve
   */
  function proposal_addCKESToReserve() private {
    if (IReserve(reserveProxy).isStableAsset(stableTokenKESProxy) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(IReserve(0).addToken.selector, stableTokenKESProxy)
        )
      );
    } else {
      console.log("Token already added to the reserve, skipping: %s", stableTokenKESProxy);
    }
  }

  /**
   * @notice enable gas payments with cKES
   */
  function proposal_enableGasPaymentsWithCKES() private {
    address feeCurrencyWhitelistProxy = contracts.celoRegistry("FeeCurrencyWhitelist");
    address[] memory whitelist = IFeeCurrencyWhitelist(feeCurrencyWhitelistProxy).getWhitelist();
    for (uint256 i = 0; i < whitelist.length; i++) {
      if (whitelist[i] == stableTokenKESProxy) {
        console.log("Gas payments with cKES already enabled, skipping");
        return;
      }
    }
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        feeCurrencyWhitelistProxy,
        abi.encodeWithSelector(IFeeCurrencyWhitelist(0).addToken.selector, stableTokenKESProxy)
      )
    );
  }

  /**
   * @notice Creates the exchange for the new pool.
   */
  function proposal_createExchange(cKESConfig.cKES memory config) private {
    IBiPoolManager.PoolExchange memory pool = IBiPoolManager.PoolExchange({
      asset0: config.poolConfig.asset0,
      asset1: config.poolConfig.asset1,
      pricingModule: IPricingModule(contracts.deployed("ConstantProductPricingModule")),
      bucket0: 0,
      bucket1: 0,
      lastBucketUpdate: 0,
      config: IBiPoolManager.PoolConfig({
        spread: FixidityLib.wrap(config.poolConfig.spread.unwrap()),
        referenceRateFeedID: config.poolConfig.referenceRateFeedID,
        referenceRateResetFrequency: config.poolConfig.referenceRateResetFrequency,
        minimumReports: config.poolConfig.minimumReports,
        stablePoolResetSize: config.poolConfig.stablePoolResetSize
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

  /**
   * @notice This function creates the transactions to configure the trading limits.
   */
  function proposal_configureTradingLimits(cKESConfig.cKES memory config) private {
    // Set the trading limit for asset0 of the pool
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxy,
        abi.encodeWithSelector(
          Broker(0).configureTradingLimit.selector,
          POOL_EXCHANGE_ID,
          config.poolConfig.asset0,
          TradingLimits.Config({
            timestep0: config.poolConfig.asset0limits.timeStep0,
            timestep1: config.poolConfig.asset0limits.timeStep1,
            limit0: config.poolConfig.asset0limits.limit0,
            limit1: config.poolConfig.asset0limits.limit1,
            limitGlobal: config.poolConfig.asset0limits.limitGlobal,
            flags: Config.tradingLimitConfigToFlag(config.poolConfig.asset0limits)
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
          POOL_EXCHANGE_ID,
          config.poolConfig.asset1,
          TradingLimits.Config({
            timestep0: config.poolConfig.asset1limits.timeStep0,
            timestep1: config.poolConfig.asset1limits.timeStep1,
            limit0: config.poolConfig.asset1limits.limit0,
            limit1: config.poolConfig.asset1limits.limit1,
            limitGlobal: config.poolConfig.asset1limits.limitGlobal,
            flags: Config.tradingLimitConfigToFlag(config.poolConfig.asset1limits)
          })
        )
      )
    );
  }

  /**
   * @notice This function creates the transactions to configure the Breakerbox.
   */
  function proposal_configureBreakerBox(cKESConfig.cKES memory config) private {
    // Add the new rate feed to breaker box
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBox,
        abi.encodeWithSelector(BreakerBox(0).addRateFeeds.selector, Arrays.addresses(config.rateFeedConfig.rateFeedID))
      )
    );

    Config.RateFeed memory rateFeed = config.rateFeedConfig;

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
  }

  /**
   * @notice This function creates the transactions to configure the Median Delta Breaker.
   */
  function proposal_configureMedianDeltaBreaker(cKESConfig.cKES memory config) private {
    // Set the cooldown time
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setCooldownTime.selector,
          Arrays.addresses(config.rateFeedConfig.rateFeedID),
          Arrays.uints(config.rateFeedConfig.medianDeltaBreaker0.cooldown)
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
          Arrays.addresses(config.rateFeedConfig.rateFeedID),
          Arrays.uints(config.rateFeedConfig.medianDeltaBreaker0.threshold.unwrap())
        )
      )
    );
  }
}
