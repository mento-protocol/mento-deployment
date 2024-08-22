// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IOwnableLite {
  function owner() external view returns (address);

  function transferOwnership(address recipient) external;
}

interface IProxyLite {
  function _getImplementation() external view returns (address);
}

contract MU08 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  // Celo Governance:
  address private celoGovernance;

  // Mento contracts:

  //Tokens:
  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address private eXOFProxy;
  address private cKESProxy;
  //address private POSProxy;

  // MentoV2 contracts:
  address private brokerProxy;
  address private biPoolMangerProxy;
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
  address private timelockProxy;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  /**
   * @dev Loads the deployed contracts from previous deployments
   */
  function loadDeployedContracts() public {
    contracts.load("MU01-00-Create-Proxies", "latest");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");
    contracts.load("cKES-00-Create-Proxies", "latest");
    //contracts.load("PSO-00-Create-Proxies", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // Celo Governance:
    celoGovernance = contracts.celoRegistry("Governance");

    // Tokens:
    cUSDProxy = address(uint160(contracts.celoRegistry("StableToken")));
    cEURProxy = address(uint160(contracts.celoRegistry("StableTokenEUR")));
    cBRLProxy = address(uint160(contracts.celoRegistry("StableTokenBRL")));
    eXOFProxy = address(uint160(contracts.deployed("StableTokenXOFProxy")));
    cKESProxy = address(uint160(contracts.deployed("StableTokenKESProxy")));
    //POSProxy = address(uint160(contracts.deployed("StableTokenPOSProxy")));

    // MentoV2 contracts:
    brokerProxy = address(uint160(contracts.deployed("BrokerProxy")));
    biPoolMangerProxy = address(uint160(contracts.deployed("BiPoolManagerProxy")));
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
    timelockProxy = IGovernanceFactory(contracts.dependency("GovernanceFactory")).governanceTimelock();
  }

  function run() public {
    prepare();

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "https://TODO", celoGovernance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    proposal_transferTokenOwnership();
    proposal_transferMentoV2Ownership();
    proposal_transferMentoV1Ownership();

    return transactions;
  }

  function proposal_transferTokenOwnership() public {
    address[] memory tokenProxies = Arrays.addresses(cUSDProxy, cEURProxy, cBRLProxy, eXOFProxy, cKESProxy);
    //address[] memory tokenProxies = Arrays.addresses(cUSDProxy, cEURProxy, cBRLProxy, eXOFProxy, cKESProxy, POSProxy);
    for (uint i = 0; i < tokenProxies.length; i++) {
      address proxyOwner = IOwnableLite(tokenProxies[i]).owner();
      // Transfer ownership of the token proxies
      if (proxyOwner != timelockProxy) {
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: tokenProxies[i],
            data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
          })
        );
      }
    }
    // Transfer ownership of the StableTokenV2 implemntation used by all proxies
    address stableTokenImplementation = IProxyLite(cUSDProxy)._getImplementation();
    address implementationOwner = IOwnableLite(stableTokenImplementation).owner();

    if (implementationOwner != timelockProxy) {
      require(implementationOwner == celoGovernance, "StableTokenV2 implementation owner is not Celo governance");
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: stableTokenImplementation,
          data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
        })
      );
    }
  }

  function proposal_transferMentoV2Ownership() public {
    // Transfer ownership of the MentoV2 upgradeable contracts
    address[] memory mentoV2Proxies = Arrays.addresses(brokerProxy, biPoolMangerProxy, reserveProxy);
    for (uint i = 0; i < mentoV2Proxies.length; i++) {
      address proxyOwner = IOwnableLite(mentoV2Proxies[i]).owner();
      if (proxyOwner != timelockProxy) {
        require(proxyOwner == celoGovernance, "MentoV2 proxy contract owner is not Celo governance");
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: mentoV2Proxies[i],
            data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
          })
        );
      }
      address implementation = IProxyLite(mentoV2Proxies[i])._getImplementation();
      address implementationOwner = IOwnableLite(implementation).owner();
      if (implementationOwner != timelockProxy) {
        require(implementationOwner == celoGovernance, "MentoV2 contract implementation owner is not Celo governance");
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: implementation,
            data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
          })
        );
      }
    }

    // Transfer ownership of the MentoV2 Nonupgradeable contracts
    address[] memory mentoV2NonupgradeableContracts = Arrays.addresses(
      breakerBox,
      medianDeltaBreaker,
      valueDeltaBreaker
    );
    for (uint i = 0; i < mentoV2NonupgradeableContracts.length; i++) {
      address contractOwner = IOwnableLite(mentoV2NonupgradeableContracts[i]).owner();
      if (contractOwner != timelockProxy) {
        require(contractOwner == celoGovernance, "MentoV2 nonupgradeable contract owner is not Celo governance");
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: mentoV2NonupgradeableContracts[i],
            data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
          })
        );
      }
    }
  }

  function proposal_transferMentoV1Ownership() public {
    // Transfer ownership of the MentoV1 upgradeable contracts
    address[] memory mentoV1Proxies = Arrays.addresses(
      exchangeProxy,
      exchangeEURProxy,
      exchangeBRLProxy,
      grandaMentoProxy
    );
    for (uint i = 0; i < mentoV1Proxies.length; i++) {
      address proxyOwner = IOwnableLite(mentoV1Proxies[i]).owner();
      if (proxyOwner != timelockProxy) {
        require(proxyOwner == celoGovernance, "MentoV1 proxy contract owner is not Celo governance");
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: mentoV1Proxies[i],
            data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
          })
        );
      }
      address implementation = IProxyLite(mentoV1Proxies[i])._getImplementation();
      address implementationOwner = IOwnableLite(implementation).owner();
      // Some of the Mento V1 implementations are owned by cLabs addresses.
      // since it's deprecated MentoV1 and only the implementations we are fine with them
      // not being owned by Mento Governance
      if (implementationOwner == celoGovernance) {
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: implementation,
            data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
          })
        );
      }
    }
  }
}
