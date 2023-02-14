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

import { BreakerBoxProxy } from "mento-core/contracts/proxies/BreakerBoxProxy.sol";
import { BiPoolManagerProxy } from "mento-core/contracts/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core/contracts/proxies/BrokerProxy.sol";
import { Broker } from "mento-core/contracts/Broker.sol";
import { BiPoolManager } from "mento-core/contracts/BiPoolManager.sol";
import { BreakerBox } from "mento-core/contracts/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core/contracts/MedianDeltaBreaker.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract MU01_BaklavaCGP is GovernanceScript {
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
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "1674224321");
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
  }

  /**
   * @dev Sets the various values needed for the configuration of the new pools.
   *      This function is called by the governance script runner.
   */
  function setUpPoolConfigs() public {
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
      valueDeltaBreakerCooldown: 0
    });

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
      valueDeltaBreakerCooldown: 0
    });

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
      valueDeltaBreakerCooldown: 0
    });

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
      valueDeltaBreakerCooldown: 1
    });
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
    proposal_configureReserve();
    proposal_registryUpdates();
    proposal_createExchanges();
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
        abi.encodeWithSelector(cBRL/CELO pool
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
            IReserve(reserve),cBRL/CELO pool
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
    if (IReserve(reserveProxy).isExchangeSpender(contracts.deployed("BrokerProxy")) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(IReserve(0).addExchangeSpender.selector, contracts.deployed("BrokerProxy"))
        )
      );
    }

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

  function proposal_createExchanges() private {
    // Add pools to the BiPoolManager: cUSD/CELO, cEUR/CELO, cBRL/CELO, cUSD/USDCet

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
        referenceRateFeedID: cEUR,
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
        referenceRateFeedID: cBRL,
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
        referenceRateFeedID: address(uint256(keccak256(abi.encodePacked("USDCUSD")))),  
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

  function proposal_configureCircuitBreaker() private {
    // Add all breakers to the breaker box
    // Add rate feeds to breaker box
    // BreakerBox.Toggle breaker -> to enable a breaker for a specific rate feed
    // For the specific breaker configuire values required for the rate feeds

    // Load necessary addresses
    address breakerBoxProxyAddress = contracts.deployed("BreakerBoxProxy");
    address medianDeltaBreakerAddress = contracts.deployed("MedianDeltaBreaker");
    address valueDeltaBreakerAddress = contracts.deployed("ValueDeltaBreaker");

    address[] memory allRateFeedIds = new address[](3);
    allRateFeedIds[0] = cUSD;
    allRateFeedIds[1] = cEUR;
    allRateFeedIds[2] = cBRL;

    PoolConfiguration[] memory poolConfigs = new PoolConfiguration[](3);
    poolConfigs[0] = cUSDCeloConfig;
    poolConfigs[1] = cEURCeloConfig;
    poolConfigs[2] = cBRLCeloConfig;

    // Add the Median Delta Breaker to the breaker box with the trading mode '1' -> No Trading
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBoxProxyAddress,
        abi.encodeWithSelector(BreakerBox(0).addBreaker.selector, medianDeltaBreakerAddress, 1)
      )
    );

    // Add the Value Delta Breaker to the breaker box with the trading mode '2' -> Also No Trading ?
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBoxProxyAddress,
        abi.encodeWithSelector(BreakerBox(0).addBreaker.selector, valueDeltaBreakerAddress, 2)
      )
    );

    // Add rateFeedIds to the breaker box to be monitored
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBoxProxyAddress,
        abi.encodeWithSelector(BreakerBox(0).addRateFeeds.selector, allRateFeedIds)
      )
    );

    // Configure Median Delta Breaker -> Set cooldowns

    /*for (uint256 i = 0; i < pools.poolConfigs; i++) {
      if (pools[i].asset0 != address(0)) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            medianDeltaBreakerAddress,
            abi.encodeWithSelector(MedianDeltaBreaker(0).createExchange.selector, pools[i])
          )
        );
      }
    }*/
  }

  // TODO: Configure breaker box

  // TODO: Configure Trading Limits
}
