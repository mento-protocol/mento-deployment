// SPDX-License-Identifier: GPL-3.0-or-later
// pragma solidity ^0.5.13;
pragma solidity >=0.5.13 <0.9.0;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { GovernanceScript } from "script/utils/mento/Script.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IOwnableLite {
  function owner() external view returns (address);

  function transferOwnership(address recipient) external;
}

interface IProxyLite {
  function _getImplementation() external view returns (address);

  function _getOwner() external view returns (address);
}

contract MU08RevertChecks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

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
  address private cGHSProxy;

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
    contracts.loadSilent("PUSO-00-Create-Proxies", "latest");
    contracts.loadSilent("cCOP-00-Create-Proxies", "latest");
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");
    contracts.loadSilent("MU08-00-Create-Proxies", "latest");
    contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");

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
    cGHSProxy = address(contracts.deployed("StableTokenGHSProxy"));

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
  }

  function run() public {
    prepare();

    console.log("\n====MU08 Revert (transferribg back to Celo Gov)====\n");
    console.log("Old owner (timelock):", timelockProxy);
    console.log("New owner (celo gov):", celoGovernance);

    verifyTokenOwnership();
    verifyMentoV2Ownership();
    verifyMentoV1Ownership();
    verifyGovernanceFactoryOwnership();
  }

  function verifyTokenOwnership() public {
    console.log("\n== Verifying token proxy and implementation ownership: ==");
    address[] memory tokenProxies = Arrays.addresses(
      cUSDProxy,
      cEURProxy,
      cBRLProxy,
      eXOFProxy,
      cKESProxy,
      PUSOProxy,
      cCOPProxy,
      cGHSProxy
    );

    for (uint256 i = 0; i < tokenProxies.length; i++) {
      verifyProxyAndImplementationOwnership(tokenProxies[i]);
    }
    console.log(unicode"🤘🏼Token proxies and implementations ownership transferred to Celo Governance🤘🏼");
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
    console.log(unicode"🤘🏼MentoV2 contract ownerships transferred to Celo Governance🤘🏼");
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
    console.log(unicode"🤘🏼MentoV1 contract ownerships transferred to Celo Governance🤘🏼");
  }

  function verifyGovernanceFactoryOwnership() public {
    console.log("\n== Verifying GovernanceFactory ownership: ==");
    verifyNonupgradeableContractsOwnership(governanceFactory);
    console.log(unicode"🤘🏼GovernanceFactory ownership transferred to Celo Governance🤘🏼");
  }

  function verifyProxyAndImplementationOwnership(address proxy) internal {
    address proxyOwner = IOwnableLite(proxy).owner();
    require(proxyOwner == celoGovernance, "[ERROR] - Proxy ownership not transferred to Celo Gov");
    console.log("[OK] - Proxy:[%s] ownership transferred to Celo Gov", proxy);

    address proxyAdmin = IProxyLite(proxy)._getOwner();
    require(proxyAdmin == celoGovernance, "[ERROR] - Proxy admin ownership not transferred to Celo Gov");
    console.log("[OK] - Proxy:[%s] admin ownership transferred to Celo Gov", proxy);

    address implementation = IProxyLite(proxy)._getImplementation();
    address implementationOwner = IOwnableLite(implementation).owner();
    require(implementationOwner != address(0), "[ERROR] - Implementation not owned by anybody");

    // Note: Mento V1 contracts are owned by the original deployer address and not by Celo Governance,
    // so we are not able to transfer them. Since they are deprecated anyways we are fine with this.
    if (implementationOwner != celoGovernance && !isMentoV1Contract(proxy)) {
      console.log("[WARNING] - Warning Implementation:[%s] ownership not transferred to Celo Gov ", implementation);
    } else if (implementationOwner == celoGovernance) {
      console.log("[OK] - Implementation:[%s] ownership transferred to Celo Gov", implementation);
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
    require(contractOwner == celoGovernance, "[ERROR] - Contract ownership not transferred to Celo Gov");
    console.log("[OK] - Contract:[%s] ownership transferred to Celo Gov", nonupgradeableContract);
  }
}
