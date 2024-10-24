// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { FixidityLib } from "mento-core-2.3.1/common/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.3.1/interfaces/IBiPoolManager.sol";
import { IPricingModule } from "mento-core-2.3.1/interfaces/IPricingModule.sol";
import { IReserve } from "mento-core-2.3.1/interfaces/IReserve.sol";
import { IFeeCurrencyWhitelist } from "../../interfaces/IFeeCurrencyWhitelist.sol";
import { IStableTokenV2 } from "mento-core-2.3.1/interfaces/IStableTokenV2.sol";
import { IERC20Metadata } from "mento-core-2.3.1/common/interfaces/IERC20Metadata.sol";

import { Broker } from "mento-core-2.3.1/swap/Broker.sol";
import { TradingLimits } from "mento-core-2.3.1/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.3.1/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.3.1/oracles/breakers/MedianDeltaBreaker.sol";
import { StableTokenCOPProxy } from "mento-core-2.3.1/legacy/proxies/StableTokenCOPProxy.sol";

import { cCOPConfig, Config } from "./Config.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract cCOP is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  ICeloGovernance.Transaction[] private transactions;

  address payable private stableTokenCOPProxy;

  address private breakerBox;
  address private medianDeltaBreaker;
  address private brokerProxy;
  address private biPoolManagerProxy;
  address private reserveProxy;
  address private validators;

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
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest"); // Pricing Modules
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment
    contracts.load("cCOP-00-Create-Proxies", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // Tokens
    stableTokenCOPProxy = contracts.deployed("StableTokenCOPProxy");

    // Oracles
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");

    // Swaps
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    reserveProxy = contracts.celoRegistry("Reserve");

    validators = contracts.celoRegistry("Validators");
  }

  function run() public {
    prepare();

    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(
        _transactions,
        "https://github.com/celo-org/governance/blob/797c8ebe91240b641e1b0a9ce2c6ceb24698f0ff/CGPs/cgp-0151.md",
        governance
      );
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    cCOPConfig.cCOP memory config = cCOPConfig.get(contracts);

    proposal_initializeCOPToken(config);
    proposal_configureCOPConstitutionParameters();
    proposal_addCOPToReserve();

    proposal_enableGasPaymentsWithCOP();

    proposal_createExchange(config);
    proposal_configureTradingLimits(config);
    proposal_configureBreakerBox(config);
    proposal_configureMedianDeltaBreaker(config);

    return transactions;
  }

  /**
   * @notice Configures the cCOP token
   */
  function proposal_initializeCOPToken(cCOPConfig.cCOP memory config) private {
    StableTokenCOPProxy _cCOPProxy = StableTokenCOPProxy(stableTokenCOPProxy);
    if (_cCOPProxy._getImplementation() == address(0)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          stableTokenCOPProxy,
          abi.encodeWithSelector(
            _cCOPProxy._setAndInitializeImplementation.selector,
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
          stableTokenCOPProxy,
          abi.encodeWithSelector(
            IStableTokenV2(0).initializeV2.selector,
            brokerProxy,
            validators,
            address(0) // Exchange address (not used)
          )
        )
      );
    } else {
      console.log("StableTokenCOPProxy is already initialized, skipping initialization.");
    }
  }

  /**
   * @notice configure cCOP constitution parameters
   * @dev see cBRl GCP(https://celo.stake.id/#/proposal/49) for reference
   */
  function proposal_configureCOPConstitutionParameters() private {
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
            stableTokenCOPProxy,
            constitutionFunctionSelectors[i],
            constitutionThresholds[i]
          )
        )
      );
    }
  }

  /**
   * @notice adds cCOP token to the main reserve
   */
  function proposal_addCOPToReserve() private {
    if (IReserve(reserveProxy).isStableAsset(stableTokenCOPProxy) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(IReserve(0).addToken.selector, stableTokenCOPProxy)
        )
      );
    } else {
      console.log("Token already added to the reserve, skipping: %s", stableTokenCOPProxy);
    }
  }

  /**
   * @notice enable gas payments with cCOP
   */
  function proposal_enableGasPaymentsWithCOP() private {
    address feeCurrencyWhitelistProxy = contracts.celoRegistry("FeeCurrencyWhitelist");
    address[] memory whitelist = IFeeCurrencyWhitelist(feeCurrencyWhitelistProxy).getWhitelist();
    for (uint256 i = 0; i < whitelist.length; i++) {
      if (whitelist[i] == stableTokenCOPProxy) {
        console.log("Gas payments with cCOP already enabled, skipping");
        return;
      }
    }
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        feeCurrencyWhitelistProxy,
        abi.encodeWithSelector(IFeeCurrencyWhitelist(0).addToken.selector, stableTokenCOPProxy)
      )
    );
  }

  /**
   * @notice Creates the exchange for the new pool.
   */
  function proposal_createExchange(cCOPConfig.cCOP memory config) private {
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    IBiPoolManager.PoolExchange memory pool = IBiPoolManager.PoolExchange({
      asset0: config.poolConfig.asset0,
      asset1: config.poolConfig.asset1,
      pricingModule: config.poolConfig.isConstantSum ? constantSum : constantProduct,
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
  function proposal_configureTradingLimits(cCOPConfig.cCOP memory config) private {
    bytes32 exchangeId = keccak256(
      abi.encodePacked("cUSD", "cCOP", config.poolConfig.isConstantSum ? "ConstantSum" : "ConstantProduct")
    );

    // Set the trading limit for asset0 of the pool
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxy,
        abi.encodeWithSelector(
          Broker(0).configureTradingLimit.selector,
          exchangeId,
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
          exchangeId,
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
  function proposal_configureBreakerBox(cCOPConfig.cCOP memory config) private {
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
  function proposal_configureMedianDeltaBreaker(cCOPConfig.cCOP memory config) private {
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

    // Set the smoothing factor
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        medianDeltaBreaker,
        abi.encodeWithSelector(
          MedianDeltaBreaker(0).setSmoothingFactor.selector,
          config.rateFeedConfig.rateFeedID,
          config.rateFeedConfig.medianDeltaBreaker0.smoothingFactor
        )
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
