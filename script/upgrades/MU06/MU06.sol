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

import { Broker } from "mento-core-2.4.0/swap/Broker.sol";
import { TradingLimits } from "mento-core-2.4.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.4.0/oracles/BreakerBox.sol";
import { ValueDeltaBreaker } from "mento-core-2.4.0/oracles/breakers/ValueDeltaBreaker.sol";
import { Reserve } from "mento-core-2.4.0/swap/Reserve.sol";

import { MU06Config, Config } from "./Config.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract MU06 is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  ICeloGovernance.Transaction[] private transactions;

  // Tokens
  address private cUSD;
  address private nativeUSDT;
  address private nativeUSDC;
  address private bridgedUSDC;

  // Mento contracts
  address private breakerBox;
  address private valueDeltaBreaker;
  address private brokerProxy;
  address private biPoolManagerProxy;
  address payable private reserveProxy;

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
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest"); // Value Delta Breaker
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts", "latest"); // BreakerBox & ConstantSumPricingModule
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // Tokens
    cUSD = contracts.celoRegistry("StableToken");
    nativeUSDT = contracts.dependency("NativeUSDT");
    nativeUSDC = contracts.dependency("NativeUSDC");
    bridgedUSDC = contracts.dependency("BridgedUSDC");

    // Oracles
    breakerBox = contracts.deployed("BreakerBox");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");

    // Swaps
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    reserveProxy = address(uint160(contracts.celoRegistry("Reserve")));
  }

  function run() public {
    prepare();

    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "SET ME PLS :'(", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    MU06Config.MU06 memory config = MU06Config.get(contracts);

    // Add USDT to the reserve as a collateral asset
    proposal_addUSDTToReserve();

    // Destroy the existing cUSD/USDC exchanges
    proposal_destroyExchanges(config);

    // Create the exchanges
    proposal_createExchanges(config);

    // Configure the trading limits
    proposal_configureTradingLimits(config);

    // Configure the breaker box
    proposal_configureBreakerBox(config);

    // Configure the value delta breaker
    proposal_configureValueDeltaBreaker(config);
    return transactions;
  }

  /**
   * @notice This function creates the transactions to add native USDT to the reserve as a collateral asset.
   *         It also sets the daily spending ratio for native USDT to 100%.
   */
  function proposal_addUSDTToReserve() private {
    // addCollateralAsset will throw if it's already added
    if (Reserve(reserveProxy).isCollateralAsset(nativeUSDT) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(Reserve(0).addCollateralAsset.selector, nativeUSDT)
        )
      );
    }

    // Set native USDT daily spending ratio to 100%
    if (Reserve(reserveProxy).getDailySpendingRatioForCollateralAsset(nativeUSDT) != FixidityLib.fixed1().unwrap()) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(
            Reserve(0).setDailySpendingRatioForCollateralAssets.selector,
            Arrays.addresses(nativeUSDT),
            Arrays.uints(FixidityLib.fixed1().unwrap())
          )
        )
      );
    }
  }

  /**
   * @notice This function creates the transactions to destroy the existing cUSD/USDC pairs
   * to redeploy them in the next step.
   */

  function proposal_destroyExchanges(MU06Config.MU06 memory config) private {
    bytes32[2] memory exchangeIds;
    exchangeIds[0] = getExchangeId(config.cUSDUSDC.asset0, config.cUSDUSDC.asset1, config.cUSDUSDC.isConstantSum);
    exchangeIds[1] = getExchangeId(
      config.cUSDaxlUSDC.asset0,
      config.cUSDaxlUSDC.asset1,
      config.cUSDaxlUSDC.isConstantSum
    );

    //it's ok to hardcode the indexes here since the transaction would fail if index and identifier don't match
    uint256[2] memory exchangeIndices;
    exchangeIndices[0] = 9; // cUSD/USDC
    require(
      IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeIds[0]).asset0 == config.cUSDUSDC.asset0,
      "Wrong exchange idx"
    );
    require(
      IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeIds[0]).asset1 == config.cUSDUSDC.asset1,
      "Wrong exchange idx"
    );

    exchangeIndices[1] = 3; // cUSD/axL/USDC
    require(
      IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeIds[1]).asset0 == config.cUSDaxlUSDC.asset0,
      "Wrong exchange idx"
    );
    require(
      IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeIds[1]).asset1 == config.cUSDaxlUSDC.asset1,
      "Wrong exchange idx"
    );

    for (uint256 i = 0; i < exchangeIndices.length; i++) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          biPoolManagerProxy,
          abi.encodeWithSelector(IBiPoolManager(0).destroyExchange.selector, exchangeIds[i], exchangeIndices[i])
        )
      );
    }
  }

  /**
   * @notice Creates the exchange for the new native USDT pool and the destroyed USDC pools
   */
  function proposal_createExchanges(MU06Config.MU06 memory config) private {
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    for (uint256 i = 0; i < config.pools.length; i++) {
      IBiPoolManager.PoolExchange memory pool = IBiPoolManager.PoolExchange({
        asset0: config.pools[i].asset0,
        asset1: config.pools[i].asset1,
        pricingModule: config.pools[i].isConstantSum ? constantSum : constantProduct,
        bucket0: 0,
        bucket1: 0,
        lastBucketUpdate: 0,
        config: IBiPoolManager.PoolConfig({
          spread: FixidityLib.wrap(config.pools[i].spread.unwrap()),
          referenceRateFeedID: config.pools[i].referenceRateFeedID,
          referenceRateResetFrequency: config.pools[i].referenceRateResetFrequency,
          minimumReports: config.pools[i].minimumReports,
          stablePoolResetSize: config.pools[i].stablePoolResetSize
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
  function proposal_configureTradingLimits(MU06Config.MU06 memory config) private {
    Config.Pool memory pool = config.cUSDUSDT;

    bytes32 exchangeId = getExchangeId(pool.asset0, pool.asset1, pool.isConstantSum);

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
  }

  /**
   * @notice This function creates the transactions to configure the Breakerbox.
   */
  function proposal_configureBreakerBox(MU06Config.MU06 memory config) private {
    Config.RateFeed memory rateFeed = config.rateFeedConfig;

    // Add the new rate feed to breaker box
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBox,
        abi.encodeWithSelector(BreakerBox(0).addRateFeeds.selector, Arrays.addresses(rateFeed.rateFeedID))
      )
    );

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

  /**
   * @notice This function creates the transactions to configure the Value Delta Breaker.
   */
  function proposal_configureValueDeltaBreaker(MU06Config.MU06 memory config) private {
    Config.RateFeed memory rateFeed = config.rateFeedConfig;

    // Set the reference value for the USDT/USD rate feed
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setReferenceValues.selector,
          Arrays.addresses(rateFeed.rateFeedID),
          Arrays.uints(rateFeed.valueDeltaBreaker0.referenceValue)
        )
      )
    );

    // Set cooldown time for USDT/USD rate feed
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setCooldownTimes.selector,
          Arrays.addresses(rateFeed.rateFeedID),
          Arrays.uints(rateFeed.valueDeltaBreaker0.cooldown)
        )
      )
    );

    // Set threshold for USDT/USD rate feed
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        valueDeltaBreaker,
        abi.encodeWithSelector(
          ValueDeltaBreaker(0).setRateChangeThresholds.selector,
          Arrays.addresses(rateFeed.rateFeedID),
          Arrays.uints(rateFeed.valueDeltaBreaker0.threshold.unwrap())
        )
      )
    );
  }
}
