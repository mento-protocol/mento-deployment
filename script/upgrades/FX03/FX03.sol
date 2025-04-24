// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IFeeCurrencyDirectory } from "../../interfaces/IFeeCurrencyDirectory.sol";

import { FixidityLib } from "mento-core-2.3.1/common/FixidityLib.sol";
import { IRegistry } from "celo/contracts/common/interfaces/IRegistry.sol";

import { Proxy } from "mento-core-2.3.1/common/Proxy.sol";
import { IReserve } from "mento-core-2.3.1/interfaces/IReserve.sol";
import { IERC20Metadata } from "mento-core-2.3.1/common/interfaces/IERC20Metadata.sol";
import { IStableTokenV2 } from "mento-core-2.3.1/interfaces/IStableTokenV2.sol";
import { IPricingModule } from "mento-core-2.3.1/interfaces/IPricingModule.sol";

import { Broker } from "mento-core-2.3.1/swap/Broker.sol";
import { IBiPoolManager } from "mento-core-2.3.1/interfaces/IBiPoolManager.sol";
import { TradingLimits } from "mento-core-2.3.1/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.3.1/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.3.1/oracles/breakers/MedianDeltaBreaker.sol";

import { FX03Config, Config } from "./Config.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

contract FX03 is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  ICeloGovernance.Transaction[] private transactions;

  //tokens
  address payable public stableTokenV2;

  //other contracts
  address private breakerBox;
  address private medianDeltaBreaker;
  address private brokerProxy;
  address private biPoolManagerProxy;
  address private reserveProxy;
  address private validators;
  address private sortedOraclesProxy;

  bool public hasChecks = true;

  // Helper mapping to store the exchange IDs for the reference rate feeds
  mapping(address => bytes32) public referenceRateFeedIDToExchangeId;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
    setUpConfigs();
  }

  /**
   * @dev Loads the deployed contracts from the previous deployments
   */
  function loadDeployedContracts() public {
    contracts.load("MU01-00-Create-Proxies"); // BrokerProxy & BiPoolProxy
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts"); // Pricing Modules
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts");
    contracts.load("MU04-00-Create-Implementations"); // First StableTokenV2 deployment

    // TODO: To be created, confirm name and update
    contracts.load("FX02-00-Deploy-Proxys");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // tokens
    stableTokenV2 = contracts.deployed("StableTokenV2");

    // Oracles
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    sortedOraclesProxy = contracts.celoRegistry("SortedOracles");

    // Swaps
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    reserveProxy = contracts.celoRegistry("Reserve");

    validators = contracts.celoRegistry("Validators");
  }

  /**
   * @dev Setups up various configuration structs.
   *      This function is called by the governance script runner.
   */
  function setUpConfigs() public {
    // Create pool configurations
    FX03Config.FX03 memory config = FX03Config.get(contracts);

    // Set the exchange ID for the reference rate feed
    for (uint i = 0; i < config.pools.length; i++) {
      referenceRateFeedIDToExchangeId[config.pools[i].referenceRateFeedID] = getExchangeId(
        config.pools[i].asset0,
        config.stableTokenConfigs[i].symbol,
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
      // TODO: confirm proposal github link
      createProposal(_transactions, "TODO", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    FX03Config.FX03 memory config = FX03Config.get(contracts);

    for (uint256 i = 0; i < config.stableTokenAddresses.length; i++) {
      proposal_initializeToken(
        config.stableTokenAddresses[i],
        config.stableTokenConfigs[i].name,
        config.stableTokenConfigs[i].symbol
      );
      proposal_configureConstitutionParameters(config.stableTokenAddresses[i]);
      proposal_addTokenToReserve(config.stableTokenAddresses[i]);
      proposal_enableGasPayments(config.stableTokenAddresses[i]);
    }

    for (uint256 i = 0; i < config.pools.length; i++) {
      proposal_createExchange(config.pools[i]);
      proposal_configureTradingLimits(config.pools[i]);
    }

    for (uint256 i = 0; i < config.rateFeeds.length; i++) {
      proosal_configureBreakerBox(config.rateFeeds[i]);
      proposal_configureMedianDeltaBreaker(config.rateFeeds[i]);
    }

    return transactions;
  }

  /**
   * @notice Configures the new stable token
   */
  function proposal_initializeToken(
    address payable stableTokenAddress,
    string memory name,
    string memory symbol
  ) private {
    if (Proxy(stableTokenAddress)._getImplementation() == address(0)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          stableTokenAddress,
          abi.encodeWithSelector(
            Proxy(0)._setAndInitializeImplementation.selector,
            stableTokenV2,
            abi.encodeWithSelector(
              IStableTokenV2(0).initialize.selector,
              name,
              symbol,
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
          stableTokenAddress,
          abi.encodeWithSelector(IStableTokenV2(0).initializeV2.selector, brokerProxy, validators, address(0))
        )
      );
    } else {
      console.log("StableToken with address %s is already initialized, skipping initialization.", stableTokenAddress);
    }
  }

  /**
   * @notice configure constitution parameters
   * @dev see cBRl GCP(https://celo.stake.id/#/proposal/49) for reference
   */
  function proposal_configureConstitutionParameters(address stableTokenAddress) private {
    address governanceProxy = contracts.celoRegistry("Governance");

    bytes4[] memory constitutionFunctionSelectors = Config.getCeloStableConstitutionSelectors();
    uint256[] memory constitutionThresholds = Config.getCeloStableConstitutionThresholds();

    for (uint256 j = 0; j < constitutionFunctionSelectors.length; j++) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          governanceProxy,
          abi.encodeWithSelector(
            ICeloGovernance(0).setConstitution.selector,
            stableTokenAddress,
            constitutionFunctionSelectors[j],
            constitutionThresholds[j]
          )
        )
      );
    }
  }

  /**
   * @notice adds the specified token to the reserve
   */
  function proposal_addTokenToReserve(address stableTokenAddress) private {
    if (IReserve(reserveProxy).isStableAsset(stableTokenAddress) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(IReserve(0).addToken.selector, stableTokenAddress)
        )
      );
    } else {
      console.log("Token already added to the reserve, skipping: %s", stableTokenAddress);
    }
  }

  /**
   * @notice enable gas payments with the specified token
   */
  function proposal_enableGasPayments(address stableTokenAddress) private {
    address feeCurrencyDirectory = contracts.celoRegistry("FeeCurrencyDirectory");
    address[] memory feeCurrencies = IFeeCurrencyDirectory(feeCurrencyDirectory).getCurrencies();
    for (uint256 i = 0; i < feeCurrencies.length; i++) {
      if (feeCurrencies[i] == stableTokenAddress) {
        console.log("Gas payments with this token %s already enabled, skipping", stableTokenAddress);
        return;
      }
    }

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        feeCurrencyDirectory,
        abi.encodeWithSelector(
          IFeeCurrencyDirectory(0).setCurrencyConfig.selector,
          stableTokenAddress,
          sortedOraclesProxy,
          50000
        )
      )
    );
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

  /**
   * @notice Helper function to get the exchange ID for a pool.
   */
  function getExchangeId(
    address asset0,
    string memory asset1Symbol,
    bool isConstantSum
  ) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          IERC20Metadata(asset0).symbol(),
          asset1Symbol,
          isConstantSum ? "ConstantSum" : "ConstantProduct"
        )
      );
  }
}
