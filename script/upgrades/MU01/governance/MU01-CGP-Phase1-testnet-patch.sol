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
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { IERC20Metadata } from "mento-core/contracts/common/interfaces/IERC20Metadata.sol";

import { BiPoolManagerProxy } from "mento-core/contracts/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core/contracts/proxies/BrokerProxy.sol";
import { Broker } from "mento-core/contracts/Broker.sol";
import { TradingLimits } from "mento-core/contracts/common/TradingLimits.sol";
import { PartialReserveProxy } from "contracts/PartialReserveProxy.sol";
import { Reserve } from "mento-core/contracts/Reserve.sol";

import { Config } from "./Config.sol";
import { ICGPBuilder } from "script/utils/ICGPBuilder.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev Testnet-only governance script creates new pools with a newly deployed BridgedUSDC 
 * and adds it as a reserve collateral. 
 * depends on: ../deploy/*.sol
 */
contract MU01_CGP_NewBridgedUSDC is ICGPBuilder, GovernanceScript {
  using TradingLimits for TradingLimits.Config;

  ICeloGovernance.Transaction[] private transactions;

  Config.PoolConfiguration private cUSDUSDCConfig;
  bytes32 private cUSDUSDCExchangeId;

  address private bridgedUSDC;
  address payable partialReserveProxy;
  address private brokerProxy;
  address payable biPoolManagerProxy;

  function prepare() public {
    loadDeployedContracts();
    setUp();
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
   * @dev Sets the contract addresses and cUSD/USDC configuration struct needed for the proposal.
   */
  function setUp() public {
    // set the addresses
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    partialReserveProxy = contracts.deployed("PartialReserveProxy");
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");

    // set up cUSD/USDC configs
    cUSDUSDCConfig = Config.cUSDUSDCConfig(contracts, 2);
    cUSDUSDCExchangeId = getExchangeId(cUSDUSDCConfig.asset0, cUSDUSDCConfig.asset1, true);
  }

  function run() public {
    prepare();
    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "MU01-testnet-patch", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    proposal_addNewBridgedUsdcToReserve();
    proposal_createExchange();
    proposal_configureTradingLimits();

    return transactions;
  }

  /**
   * @notice This function generates the transactions required to create the
   *         cUSD/bridgedUSDC exchange
   */
  function proposal_createExchange() private {
    bool biPoolManagerInitialized = BiPoolManagerProxy(biPoolManagerProxy)._getImplementation() != address(0);

    if (biPoolManagerInitialized) {
      bytes32[] memory existingExchangeIds = IBiPoolManager(biPoolManagerProxy).getExchangeIds();
      if (existingExchangeIds.length > 0) {
        for (uint256 i = 0; i < existingExchangeIds.length; i++) {
          if (existingExchangeIds[i] == cUSDUSDCExchangeId) {
            transactions.push(
              ICeloGovernance.Transaction(
                0,
                biPoolManagerProxy,
                abi.encodeWithSelector(IBiPoolManager(0).destroyExchange.selector, existingExchangeIds[i], i)
              )
            );
            console.log("Destroying existing cUSD/USDC exchange");
          }
        }
      }
    }

    // Get the address of the constantSum
    IPricingModule constantSum = IPricingModule(contracts.deployed("ConstantSumPricingModule"));

    IBiPoolManager.PoolExchange memory pool = IBiPoolManager.PoolExchange({
      asset0: cUSDUSDCConfig.asset0,
      asset1: cUSDUSDCConfig.asset1,
      pricingModule: constantSum,
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

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxy,
        abi.encodeWithSelector(IBiPoolManager(0).createExchange.selector, pool)
      )
    );
  }

  /**
   * @notice This function creates the transactions to configure the trading limits for cUSD/USDC pool.
   */
  function proposal_configureTradingLimits() public {
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxy,
        abi.encodeWithSelector(
          Broker(0).configureTradingLimit.selector,
          cUSDUSDCExchangeId,
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
   * @notice This function creates the transactions to add new mock USDC
   * with 6 decimals as a reserve asset and removes the old one.
   */
  function proposal_addNewBridgedUsdcToReserve() public {
    address[] memory oldBridgedUSDC = Arrays.addresses(
      0x4c6B046750F9aBF6F0f3B511217438451bc6Aa02,
      0x2C4B568DfbA1fBDBB4E7DAD3F4186B68BCE40Db3
    );

    for (uint i = 0; i < oldBridgedUSDC.length; i++) {
      if (Reserve(partialReserveProxy).isCollateralAsset(oldBridgedUSDC[i])) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            partialReserveProxy,
            abi.encodeWithSelector(Reserve(0).removeCollateralAsset.selector, oldBridgedUSDC[i], 0)
          )
        );
        console.log("Old bridgedUSDC removed: %s", oldBridgedUSDC[i]);
      }
    }

    if (Reserve(partialReserveProxy).isCollateralAsset(bridgedUSDC) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          partialReserveProxy,
          abi.encodeWithSelector(Reserve(0).addCollateralAsset.selector, bridgedUSDC)
        )
      );

      transactions.push(
        ICeloGovernance.Transaction(
          0,
          partialReserveProxy,
          abi.encodeWithSelector(
            Reserve(0).setDailySpendingRatioForCollateralAssets.selector,
            Arrays.addresses(bridgedUSDC),
            Arrays.uints(FixidityLib.fixed1().unwrap())
          )
        )
      );
      console.log("New bridgedUSDC added: %s", bridgedUSDC);
    } else {
      console.log("Token already added to the reserve, skipping: %s", bridgedUSDC);
    }
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