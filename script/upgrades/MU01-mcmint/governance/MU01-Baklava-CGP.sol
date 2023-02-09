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

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract MU01_BaklavaCGP is GovernanceScript {
  ICeloGovernance.Transaction[] private transactions;

  function prepare() public {
    contracts.load("MU01-00-Create-Proxies", "1674224277");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "1674224321");
    contracts.load("MU01-02-Create-Implementations", "1674225880");
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
    address[] memory rateFeedIDs = new address[](2);
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
    // TODO: confirm values
    // Add pools to the BiPoolManager: cUSD/CELO, cEUR/CELO, cBRL/CELO, cUSD/USDCet

    IBiPoolManager.PoolExchange[] memory pools = new IBiPoolManager.PoolExchange[](4);

    // Get the proxy addresses for the tokens from the registry
    address cUSD = contracts.celoRegistry("StableToken");
    address cEUR = contracts.celoRegistry("StableTokenEUR");
    address cBRL = contracts.celoRegistry("StableTokenBRL");
    address celo = contracts.celoRegistry("GoldToken");

    // Get the address of the newly deployed CPP pricing module
    IPricingModule constantProduct = IPricingModule(contracts.deployed("ConstantProductPricingModule"));

    // Create the pool configuration for cUSD/CELO
    pools[0] = IBiPoolManager.PoolExchange({
      asset0: cUSD,
      asset1: celo,
      pricingModule: constantProduct,
      bucket0: 0,
      bucket1: 0,
      lastBucketUpdate: 0,
      config: IBiPoolManager.PoolConfig({
        spread: FixidityLib.newFixedFraction(5, 100),
        referenceRateFeedID: cUSD,
        referenceRateResetFrequency: 60 * 5,
        minimumReports: 5,
        stablePoolResetSize: 1e24
      })
    });

    // Create the pool configuration for cEUR/CELO
    pools[1] = IBiPoolManager.PoolExchange({
      asset0: cEUR,
      asset1: celo,
      pricingModule: constantProduct,
      bucket0: 0,
      bucket1: 0,
      lastBucketUpdate: 0,
      config: IBiPoolManager.PoolConfig({
        spread: FixidityLib.newFixedFraction(5, 100),
        referenceRateFeedID: cEUR,
        referenceRateResetFrequency: 60 * 5,
        minimumReports: 5,
        stablePoolResetSize: 1e24
      })
    });

    // Create the pool configuration for cBRL/CELO
    pools[2] = IBiPoolManager.PoolExchange({
      asset0: cBRL,
      asset1: celo,
      pricingModule: constantProduct,
      bucket0: 0,
      bucket1: 0,
      lastBucketUpdate: 0,
      config: IBiPoolManager.PoolConfig({
        spread: FixidityLib.newFixedFraction(5, 100),
        referenceRateFeedID: cBRL,
        referenceRateResetFrequency: 60 * 5,
        minimumReports: 5,
        stablePoolResetSize: 1e24
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
}
