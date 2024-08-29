// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { GovernanceScript } from "script/utils/Script.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { Contracts } from "script/utils/Contracts.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IOwnableLite {
  function owner() external view returns (address);

  function transferOwnership(address recipient) external;
}

interface IProxyLite {
  function _getImplementation() external view returns (address);
}

contract MU08Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  // Celo Governance:
  address private celoGovernance;

  //Tokens:
  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address private eXOFProxy;
  address private cKESProxy;

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

  function prepare() public {
    // Load addresses from deployments
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("cKES-00-Create-Proxies", "latest");

    // Celo Governance:
    celoGovernance = contracts.celoRegistry("Governance");

    // Tokens:
    cUSDProxy = address(uint160(contracts.celoRegistry("StableToken")));
    cEURProxy = address(uint160(contracts.celoRegistry("StableTokenEUR")));
    cBRLProxy = address(uint160(contracts.celoRegistry("StableTokenBRL")));
    eXOFProxy = address(uint160(contracts.deployed("StableTokenXOFProxy")));
    cKESProxy = address(uint160(contracts.deployed("StableTokenKESProxy")));

    // MentoV2 contracts:
    brokerProxy = address(uint160(contracts.deployed("BrokerProxy")));
    biPoolManagerProxy = address(uint160(contracts.deployed("BiPoolManagerProxy")));
    reserveProxy = address(uint160(contracts.celoRegistry("Reserve")));
    breakerBox = address(uint160(contracts.deployed("BreakerBox")));
    medianDeltaBreaker = address(uint160(contracts.deployed("MedianDeltaBreaker")));
    valueDeltaBreaker = address(uint160(contracts.deployed("ValueDeltaBreaker")));

    // MentoV1 contracts:
    exchangeProxy = contracts.dependency("Exchange");
    exchangeEURProxy = contracts.dependency("ExchangeEUR");
    exchangeBRLProxy = contracts.dependency("ExchangeBRL");
    grandaMentoProxy = contracts.dependency("GrandaMento");

    // MentoGovernance contracts:
    governanceFactory = contracts.dependency("GovernanceFactory");
    timelockProxy = IGovernanceFactory(governanceFactory).governanceTimelock();
  }

  function run() public {
    console.log("\nStarting MU08 checks:");
    prepare();

    verifyTokenOwnership();
    verifyMentoV2Ownership();
    verifyMentoV1Ownership();
    verifyGovernanceFactoryOwnership();
  }

  function verifyTokenOwnership() public {
    console.log("\n== Verifying token proxy and implementation ownership: ==");
    address[] memory tokenProxies = Arrays.addresses(cUSDProxy, cEURProxy, cBRLProxy, eXOFProxy, cKESProxy);

    for (uint256 i = 0; i < tokenProxies.length; i++) {
      verifyProxyAndImplementationOwnership(tokenProxies[i]);
    }
    console.log("🤘🏼Token proxies and implementations ownership transferred to Mento Governance🤘🏼");
  }

  function verifyMentoV2Ownership() public {
    console.log("\n== Verifying MentoV2 contract ownerships: ==");
    address[] memory mentoV2Proxies = Arrays.addresses(brokerProxy, biPoolManagerProxy, reserveProxy);
    for (uint256 i = 0; i < mentoV2Proxies.length; i++) {
      verifyProxyAndImplementationOwnership(mentoV2Proxies[i]);
    }
    address[] memory mentoV2NonupgradeableContracts = Arrays.addresses(
      breakerBox,
      medianDeltaBreaker,
      valueDeltaBreaker
    );
    console.log("Verifying MentoV2 nonupgradeable contract ownerships:");
    for (uint256 i = 0; i < mentoV2NonupgradeableContracts.length; i++) {
      verifyNonupgradeableContractsOwnership(mentoV2NonupgradeableContracts[i]);
    }
    console.log("🤘🏼MentoV2 contract ownerships transferred to Mento Governance🤘🏼");
  }

  function verifyMentoV1Ownership() public {
    console.log("\n== Verifying MentoV1 contract ownerships: ==");
    address[] memory mentoV1Proxies = Arrays.addresses(
      exchangeProxy,
      exchangeEURProxy,
      exchangeBRLProxy,
      grandaMentoProxy
    );
    for (uint256 i = 0; i < mentoV1Proxies.length; i++) {
      verifyProxyAndImplementationOwnership(mentoV1Proxies[i]);
    }
    console.log("🤘🏼MentoV1 contract ownerships transferred to Mento Governance🤘🏼");
  }

  function verifyGovernanceFactoryOwnership() public {
    console.log("\n== Verifying GovernanceFactory ownership: ==");
    verifyNonupgradeableContractsOwnership(governanceFactory);
    console.log("🤘🏼GovernanceFactory ownership transferred to Mento Governance🤘🏼");
  }

  function verifyProxyAndImplementationOwnership(address proxy) internal {
    address proxyOwner = IOwnableLite(proxy).owner();
    require(proxyOwner == timelockProxy, "❗️❌ Proxy ownership not transferred to Mento Governance");
    console.log("🟢 Proxy:[%s] ownership transferred to Mento Governance", proxy);

    address implementation = IProxyLite(proxy)._getImplementation();
    address implementationOwner = IOwnableLite(implementation).owner();
    require(implementationOwner != address(0), "❗️❌ Implementation not owned by anybody");

    // Note: Mento V1 contracts are owned by the original deployer address and not by Celo Governance,
    // so we are not able to transfer them. Since they are deprecated anyways we are fine with this.
    if (implementationOwner != timelockProxy && !isMentoV1Contract(proxy)) {
      console.log("🟡 Warning Implementation:[%s] ownership not transferred to Mento Governance 🟡 ", implementation);
    } else {
      console.log("🟢 Implementation:[%s] ownership transferred to Mento Governance", implementation);
    }
  }

  function isMentoV1Contract(address contractAddr) internal view returns (bool) {
    return
      contractAddr == exchangeProxy ||
      contractAddr == exchangeEURProxy ||
      contractAddr == exchangeBRLProxy ||
      contractAddr == grandaMentoProxy;
  }

  function verifyNonupgradeableContractsOwnership(address nonupgradeableContract) public {
    address contractOwner = IOwnableLite(nonupgradeableContract).owner();
    require(contractOwner == timelockProxy, "❗️❌ Contract ownership not transferred to Mento Governance");
    console.log("🟢 Contract:[%s] ownership transferred to Mento Governance", nonupgradeableContract);
  }
}
