// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";

import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";
import { IPricingModule } from "mento-core-2.2.0/interfaces/IPricingModule.sol";

import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";
import { Reserve } from "mento-core-2.2.0/swap/Reserve.sol";
import { Broker } from "mento-core-2.2.0/swap/Broker.sol";

import { MU05Config, Config } from "./Config.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

contract MU05 is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  ICeloGovernance.Transaction[] private transactions;

  // Tokens
  address public cUSDProxy;
  address public cEURProxy;
  address public cBRLProxy;
  address public nativeUSDC;

  // Mento contracts
  address public brokerProxy;
  address public biPoolManagerProxy;
  address payable public reserveProxy;

  // Helper mapping to store the exchange IDs for the reference rate feeds
  mapping(address => bytes32) public referenceRateFeedIDToExchangeId;

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
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    cUSDProxy = address(uint160(contracts.celoRegistry("StableToken")));
    cEURProxy = address(uint160(contracts.celoRegistry("StableTokenEUR")));
    cBRLProxy = address(uint160(contracts.celoRegistry("StableTokenBRL")));
    nativeUSDC = contracts.dependency("NativeUSDC");

    brokerProxy = address(uint160(contracts.deployed("BrokerProxy")));
    biPoolManagerProxy = address(uint160(contracts.deployed("BiPoolManagerProxy")));
    reserveProxy = address(uint160(contracts.celoRegistry("Reserve")));
  }

  /**
   * @dev Setups up various configuration structs.
   *      This function is called by the governance script runner.
   */
  function setUpConfigs() public {
    // Create pool configurations
    MU05Config.MU05 memory config = MU05Config.get(contracts);

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
      createProposal(_transactions, "MU05", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    MU05Config.MU05 memory config = MU05Config.get(contracts);

    proposal_addNativeUSDCToReserve();
    proposal_createExchanges(config);
    proposal_configureTradingLimits(config);

    return transactions;
  }

  /**
   * @notice This function creates the transactions to add native USDC to the reserve as a collateral asset.
   *         It also sets the daily spending ratio for native USDC to 100%.
   */
  function proposal_addNativeUSDCToReserve() private {
    // addCollateralAsset will throw if it's already added
    if (Reserve(reserveProxy).isCollateralAsset(nativeUSDC) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(Reserve(0).addCollateralAsset.selector, nativeUSDC)
        )
      );
    }

    // Set native USDC daily spending ratio to 100% sames as axlUSDC
    if (Reserve(reserveProxy).getDailySpendingRatioForCollateralAsset(nativeUSDC) != FixidityLib.fixed1().unwrap()) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(
            Reserve(0).setDailySpendingRatioForCollateralAssets.selector,
            Arrays.addresses(nativeUSDC),
            Arrays.uints(FixidityLib.fixed1().unwrap())
          )
        )
      );
    }
  }

  /**
   * @notice This function creates the transactions to create the new pairs with native USDC.
   */
  function proposal_createExchanges(MU05Config.MU05 memory config) private {
    // Get the address of the pricing modules
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    Config.Pool[] memory poolsToCreate = new Config.Pool[](3);
    poolsToCreate[0] = config.cUSDUSDC;
    poolsToCreate[1] = config.cEURUSDC;
    poolsToCreate[2] = config.cBRLUSDC;

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
          biPoolManagerProxy,
          abi.encodeWithSelector(IBiPoolManager(0).createExchange.selector, pool)
        )
      );
    }
  }

  /**
   * @notice This function creates the transactions to configure the trading limits.
   */
  function proposal_configureTradingLimits(MU05Config.MU05 memory config) public {
    for (uint256 i = 0; i < config.pools.length; i++) {
      Config.Pool memory poolConfig = config.pools[i];

      // Set the trading limits for the pool
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          brokerProxy,
          abi.encodeWithSelector(
            Broker(0).configureTradingLimit.selector,
            getExchangeId(poolConfig.asset0, poolConfig.asset1, poolConfig.isConstantSum),
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
}
