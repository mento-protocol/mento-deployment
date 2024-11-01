// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.13 <0.9.0;
// pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { GovernanceScript } from "script/utils/mento/Script.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

import { IBreakerBox } from "mento-core-2.6.0/interfaces/IBreakerBox.sol";
import { IBiPoolManager } from "mento-core-2.6.0/interfaces/IBiPoolManager.sol";

interface IOwnableLite {
  function owner() external view returns (address);

  function transferOwnership(address recipient) external;
}

interface IProxyLite {
  function _getImplementation() external view returns (address);

  function _getOwner() external view returns (address);
}

contract MU09Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  // New implementations:
  address private newBrokerImplementation;
  address private newBiPoolManagerImplementation;
  address private newStableTokenV2Implementation;
  address private newReserveImplementation;

  // Celo Governance:
  address private celoGovernance;

  //Tokens:
  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address private eXOFProxy;
  address private cKESProxy;
  address private PUSOProxy;
  address private cCOPProxy;

  // MentoV2 contracts:
  address private brokerProxy;
  address private biPoolManagerProxy;
  address private reserveProxy;
  address private breakerBox;
  address private medianDeltaBreaker;
  address private valueDeltaBreaker;

  // MentoV1 contracts:
  address private exchangeProxy;
  address private exchangeEURProxy;
  address private exchangeBRLProxy;
  address private grandaMentoProxy;

  // MentoGovernance contracts:
  address private governanceFactory;
  address private timelockProxy;

  address public constantSum;

  function prepare() public {
    // Load addresses from deployments
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("cKES-00-Create-Proxies", "latest");
    contracts.loadSilent("PUSO-00-Create-Proxies", "latest");
    contracts.loadSilent("cCOP-00-Create-Proxies", "latest");
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");

    // Load new implementations
    contracts.loadSilent("MU09-00-Create-Implementations", "latest");
    newBrokerImplementation = contracts.deployed("Broker");
    newBiPoolManagerImplementation = contracts.deployed("BiPoolManager");
    newStableTokenV2Implementation = contracts.deployed("StableTokenV2");
    newReserveImplementation = contracts.deployed("Reserve");

    // Celo Governance:
    celoGovernance = contracts.celoRegistry("Governance");

    // Tokens:
    cUSDProxy = address(contracts.celoRegistry("StableToken"));
    cEURProxy = address(contracts.celoRegistry("StableTokenEUR"));
    cBRLProxy = address(contracts.celoRegistry("StableTokenBRL"));
    eXOFProxy = address(contracts.deployed("StableTokenXOFProxy"));
    cKESProxy = address(contracts.deployed("StableTokenKESProxy"));
    PUSOProxy = address(contracts.deployed("StableTokenPHPProxy"));
    cCOPProxy = address(contracts.deployed("StableTokenCOPProxy"));

    // MentoV2 contracts:
    brokerProxy = address(contracts.deployed("BrokerProxy"));
    biPoolManagerProxy = address(contracts.deployed("BiPoolManagerProxy"));
    reserveProxy = address(contracts.celoRegistry("Reserve"));
    breakerBox = address(contracts.deployed("BreakerBox"));
    medianDeltaBreaker = address(contracts.deployed("MedianDeltaBreaker"));
    valueDeltaBreaker = address(contracts.deployed("ValueDeltaBreaker"));

    // MentoV1 contracts:
    exchangeProxy = contracts.dependency("Exchange");
    exchangeEURProxy = contracts.dependency("ExchangeEUR");
    exchangeBRLProxy = contracts.dependency("ExchangeBRL");
    grandaMentoProxy = contracts.dependency("GrandaMento");

    // MentoGovernance contracts:
    governanceFactory = contracts.deployed("GovernanceFactory");
    timelockProxy = IGovernanceFactory(governanceFactory).governanceTimelock();

    constantSum = contracts.deployed("ConstantSumPricingModule");
  }

  function run() public {
    console.log("\nStarting MU09 checks:");
    prepare();

    verifyNewImplementationsSetCorrectly();
    verifycCOPPool();
    checkBreakerBoxUpdated();
  }

  function verifyNewImplementationsSetCorrectly() public {
    require(
      IProxyLite(brokerProxy)._getImplementation() == newBrokerImplementation,
      "[ERROR]: Broker implementation not set correctly"
    );
    require(IProxyLite(brokerProxy)._getOwner() == timelockProxy, "[ERROR]: Broker owner not set correctly");
    console.log("[OK] - New Broker implementation + owner set correctly");

    require(
      IProxyLite(biPoolManagerProxy)._getImplementation() == newBiPoolManagerImplementation,
      "[ERROR]: BiPoolManager implementation not set correctly"
    );
    require(
      IProxyLite(biPoolManagerProxy)._getOwner() == timelockProxy,
      "[ERROR]: BiPoolManager owner not set correctly"
    );
    console.log("[OK] - New BiPoolManager implementation + owner set correctly");

    require(
      IProxyLite(reserveProxy)._getImplementation() == newReserveImplementation,
      "[ERROR]: Reserve implementation not set correctly"
    );
    require(IProxyLite(reserveProxy)._getOwner() == timelockProxy, "[ERROR]: reserveProxy owner not set correctly");
    console.log("[OK] - New Reserve implementation + owner set correctly");

    address[] memory tokenProxies = Arrays.addresses(
      cUSDProxy,
      cEURProxy,
      cBRLProxy,
      eXOFProxy,
      cKESProxy,
      PUSOProxy,
      cCOPProxy
    );

    for (uint256 i = 0; i < tokenProxies.length; i++) {
      address implementation = IProxyLite(tokenProxies[i])._getImplementation();
      require(
        implementation == newStableTokenV2Implementation,
        "[ERROR]: StableTokenV2 implementation not set correctly"
      );
      require(
        IProxyLite(tokenProxies[i])._getOwner() == timelockProxy,
        "[ERROR]: Reserve implementation not set correctly"
      );
    }
    console.log("[OK] - StableTokenV2 implementation + owner set correctly on all tokens");
  }

  function verifycCOPPool() public {
    bytes32[] memory exchanges = IBiPoolManager(biPoolManagerProxy).getExchangeIds();

    uint256 PRE_EXISTING_POOLS = 16;
    require(exchanges.length == PRE_EXISTING_POOLS - 1, "cCOP pool not destroyed?");
    console.log("[OK] - cCOP pool destroyed successfully");
  }

  function checkBreakerBoxUpdated() public {
    address COPUSDFeed = toRateFeedId("relayed:COPUSD");
    address[] memory enabledFeeds = IBreakerBox(breakerBox).getRateFeeds();
    bool found = false;
    for (uint i = 0; i < enabledFeeds.length; i++) {
      found = false || enabledFeeds[i] == COPUSDFeed;
    }
    require(!found, "COP/USD feed still enabled on BreakerBox");

    console.log("[OK] - COP/USD feed removed from BreakerBox");
  }
}
