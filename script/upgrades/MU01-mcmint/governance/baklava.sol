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

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on deploy/00-CircuitBreaker.sol and deploy/01-Broker.sol
 */
contract MentoUpgrade1_baklava is GovernanceScript {
  ICeloGovernance.Transaction[] private transactions;

  function prepare() public {
    contracts.load("00-CircuitBreaker", "1673898407");
    contracts.load("01-Broker", "1673898735");
  }

  function run() public {
    prepare();
    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "TODO", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    proposal_upgradeContracts();
    proposal_configureReserve();
    proposal_registryUpdates();
    proposal_createExchanges();
    //TODO: Set Oracle report targets for new rates
    return transactions;
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

    // TODO: add BRL once it is deployed on Baklava
    // transactions.push(
    //   ICeloGovernance.Transaction(
    //     0,
    //     contracts.celoRegistry("StableTokenBRL"),
    //     abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("StableTokenBRL"))
    //   )
    // );
  }

  function proposal_configureReserve() private {
    address reserveProxy = contracts.celoRegistry("Reserve");
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        reserveProxy,
        abi.encodeWithSelector(IReserve(0).addExchangeSpender.selector, contracts.deployed("BrokerProxy"))
      )
    );

    // NOTE:  These assets have already been added to the Reserve in a prev deployment.
    //        As we are not deploying a new reserve proxy we do not need to add them again (tx also will fail).
    //        Leaving this here for reference when building the mainnet proposal as it will need to be included there.
    //        @Bayological

    // transactions.push(
    //   ICeloGovernance.Transaction(
    //     0,
    //     reserveProxy,
    //     abi.encodeWithSelector(IReserve(0).addCollateralAsset.selector, contracts.dependency("USDCet"))
    //   )
    // );

    // transactions.push(
    //   ICeloGovernance.Transaction(
    //     0,
    //     reserveProxy,
    //     abi.encodeWithSelector(IReserve(0).addCollateralAsset.selector, contracts.celoRegistry("GoldToken"))
    //   )
    // );
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
    // Add pools to the BiPoolManager: cUSD/CELO, cEUR/CELO, cREAL/CELO, cUSD/USDCet

    IBiPoolManager.PoolExchange[] memory pools = new IBiPoolManager.PoolExchange[](4);

    // Get the proxy addresses for the tokens from the registry
    address cUSD = contracts.celoRegistry("StableToken");
    address cEUR = contracts.celoRegistry("StableTokenEUR");
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
