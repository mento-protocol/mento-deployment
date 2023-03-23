// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
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
import { Exchange } from "mento-core/contracts/Exchange.sol";
import { MedianDeltaBreaker } from "mento-core/contracts/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core/contracts/ValueDeltaBreaker.sol";
import { TradingLimits } from "mento-core/contracts/common/TradingLimits.sol";
import { SortedOracles } from "mento-core/contracts/SortedOracles.sol";
import { Reserve } from "mento-core/contracts/Reserve.sol";
import { PartialReserveProxy } from "contracts/PartialReserveProxy.sol";

import { Config } from "./Config.sol";
import { ICGPBuilder } from "script/utils/ICGPBuilder.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract MU01_CGP_Phase2 is ICGPBuilder, GovernanceScript {
  using TradingLimits for TradingLimits.Config;

  ICeloGovernance.Transaction[] private transactions;

  Config.PoolConfiguration private cUSDCeloConfig;
  Config.PoolConfiguration private cEURCeloConfig;
  Config.PoolConfiguration private cBRLCeloConfig;
  Config.PoolConfiguration private cUSDUSDCConfig;
  Config.PoolConfiguration[] private poolConfigs;
  Config.PartialReserveConfiguration private partialReserveConfig;

  address private cUSD;
  address private cEUR;
  address private cBRL;
  address private celo;
  address private bridgedUSDC;

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
    contracts.load("MU01-00-Create-Proxies", "latest");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU01-02-Create-Implementations", "latest");
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
    breakerBoxProxyAddress = contracts.deployed("BreakerBoxProxy");
  }

  /**
   * @dev Setups up various configuration structs.
   *      This function is called by the governance script runner.
   */
  function setUpConfigs() public {
    partialReserveConfig = Config.partialReserveConfig(contracts);

    // Create pool configurations
    cUSDCeloConfig = Config.cUSDCeloConfig(contracts, 2);
    cEURCeloConfig = Config.cEURCeloConfig(contracts, 2);
    cBRLCeloConfig = Config.cBRLCeloConfig(contracts, 2);
    cUSDUSDCConfig = Config.cUSDUSDCConfig(contracts, 2);

    // Push them to the array
    poolConfigs.push(cUSDCeloConfig);
    poolConfigs.push(cEURCeloConfig);
    poolConfigs.push(cBRLCeloConfig);
    poolConfigs.push(cUSDUSDCConfig);

    // Set the exchange ID for the reference rate feed
    for (uint i = 0; i < poolConfigs.length; i++) {
      referenceRateFeedIDToExchangeId[poolConfigs[i].referenceRateFeedID] = getExchangeId(
        poolConfigs[i].asset0,
        poolConfigs[i].asset1,
        poolConfigs[i].isConstantSum
      );
    }
  }

  function run() public {
    prepare();
    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "MU01-Phase2", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    proposal_createExchanges();
    proposal_configureTradingLimits();
    proposal_configureV1Exchanges();

    return transactions;
  }

  /**
   * @notice This function generates the transactions required to create the
   *         BiPoolManager exchanges (cUSD/CELO, cEUR/CELO, cBRL/CELO, cUSD/bridgedUSDC)
   */
  function proposal_createExchanges() private {
    address payable biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    bool biPoolManagerInitialized = BiPoolManagerProxy(biPoolManagerProxy)._getImplementation() != address(0);
    if (biPoolManagerInitialized) {
      bytes32[] memory existingExchangeIds = IBiPoolManager(contracts.deployed("BiPoolManagerProxy")).getExchangeIds();
      if (existingExchangeIds.length > 0) {
        console.log("Destroying existing exchanges: ", existingExchangeIds.length);
        for (uint256 i = existingExchangeIds.length; i > 0; i--) {
          transactions.push(
            ICeloGovernance.Transaction(
              0,
              contracts.deployed("BiPoolManagerProxy"),
              abi.encodeWithSelector(IBiPoolManager(0).destroyExchange.selector, existingExchangeIds[i-1], i-1)
            )
          );
        }
      }
    }

    // Get the address of the newly deployed pricing modules
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    for (uint256 i = 0; i < poolConfigs.length; i++) {
      Config.PoolConfiguration memory poolConfig = poolConfigs[i];
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
   * @notice This function creates the transactions to configure the trading limits.
   */
  function proposal_configureTradingLimits() public {
    address brokerProxyAddress = contracts.deployed("BrokerProxy");
    for (uint256 i = 0; i < poolConfigs.length; i++) {
      Config.PoolConfiguration memory poolConfig = poolConfigs[i];

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
   * @notice This function creates the transactions to configure the Mento V1 Exchanges.
   */
  function proposal_configureV1Exchanges() public {
   address[] memory exchangesV1 = Arrays.addresses(
      contracts.celoRegistry("Exchange"),
      contracts.celoRegistry("ExchangeBRL"),
      contracts.celoRegistry("ExchangeEUR")
    );
   uint256[] memory reserveFractions = Arrays.uints(2e22, 5e21, 5e21);
   
    for(uint i = 0; i < exchangesV1.length; i++){
      Exchange exchange = Exchange(exchangesV1[i]);
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          exchangesV1[i],
          abi.encodeWithSelector(
            exchange.setReserveFraction.selector, FixidityLib.wrap(reserveFractions[i]).divide(FixidityLib.newFixed(2))
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