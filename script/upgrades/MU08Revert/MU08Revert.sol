// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
// pragma solidity ^0.5.13;
pragma solidity >=0.5.13 <0.9.0;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IOwnableLite {
  function owner() external view returns (address);

  function transferOwnership(address recipient) external;
}

interface IProxyLite {
  function _getImplementation() external view returns (address);

  function _getOwner() external view returns (address);

  function _transferOwnership(address) external;

  function _setAndInitializeImplementation(address, bytes calldata) external payable;
}

contract MU08Revert is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  // Celo Governance:
  address private celoGovernance;

  // Celo Registry:
  address private celoRegistry;

  // Mento contracts:

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
  address private mentoGovernance;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  /**
   * @dev Loads the deployed contracts from previous deployments
   */
  function loadDeployedContracts() public {
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
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // Celo Governance:
    celoGovernance = contracts.celoRegistry("Governance");

    // Celo Registry:
    celoRegistry = 0x000000000000000000000000000000000000ce10;

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
    mentoGovernance = IGovernanceFactory(governanceFactory).mentoGovernor();
  }

  function run() public {
    if (!Chain.isAlfajores()) {
      console.log("MU08Revert can only be run on Alfajores");
      return;
    }

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "TODO", mentoGovernance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    proposal_transferTokenOwnership();
    proposal_transferMentoV2Ownership();
    proposal_transferMentoV1Ownership();
    proposal_transferGovFactoryOwnership();

    return transactions;
  }

  function proposal_transferTokenOwnership() public {
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
    for (uint i = 0; i < tokenProxies.length; i++) {
      transferOwnership(tokenProxies[i]);
      transferProxyAdmin(tokenProxies[i]);
    }

    // All the token proxies are pointing to the same StableTokenV2 implementation (cUSD)
    // so we only need to transfer ownership of that single contract.
    address sharedImplementation = IProxyLite(cUSDProxy)._getImplementation();
    for (uint i = 0; i < tokenProxies.length; i++) {
      if (tokenProxies[i] == cGHSProxy) {
        // cGHS is not yet initialized, so it doesn't have an implementation
        continue;
      }

      require(
        IProxyLite(tokenProxies[i])._getImplementation() == sharedImplementation,
        "Token proxies not poiting to cUSD implementation"
      );
    }
    transferOwnership(sharedImplementation);
  }

  function proposal_transferMentoV2Ownership() public {
    address[] memory mentoV2Proxies = Arrays.addresses(brokerProxy, biPoolManagerProxy, reserveProxy);
    for (uint i = 0; i < mentoV2Proxies.length; i++) {
      transferOwnership(mentoV2Proxies[i]);
      transferProxyAdmin(mentoV2Proxies[i]);
      address implementation = IProxyLite(mentoV2Proxies[i])._getImplementation();
      transferOwnership(implementation);
    }

    address[] memory mentoV2NonupgradeableContracts = Arrays.addresses(
      breakerBox,
      medianDeltaBreaker,
      valueDeltaBreaker
    );
    for (uint i = 0; i < mentoV2NonupgradeableContracts.length; i++) {
      transferOwnership(mentoV2NonupgradeableContracts[i]);
    }
  }

  function proposal_transferMentoV1Ownership() public {
    // For some reason Mento V1 implementation contracts were not transferred to Celo Governance and are
    // owned by the original deployer address. Therefore we can only transfer ownership of the proxies.
    address[] memory mentoV1Proxies = Arrays.addresses(
      exchangeProxy,
      exchangeEURProxy,
      exchangeBRLProxy,
      grandaMentoProxy
    );
    for (uint i = 0; i < mentoV1Proxies.length; i++) {
      transferOwnership(mentoV1Proxies[i]);
      transferProxyAdmin(mentoV1Proxies[i]);
    }
  }

  function proposal_transferGovFactoryOwnership() public {
    transferOwnership(governanceFactory);
  }

  function transferOwnership(address contractAddr) internal {
    address contractOwner = IOwnableLite(contractAddr).owner();
    // if (contractOwner != timelockProxy && contractOwner == celoGovernance) {
    if (contractOwner != celoGovernance && contractOwner == timelockProxy) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: contractAddr,
          data: abi.encodeWithSelector(IOwnableLite(address(0)).transferOwnership.selector, celoGovernance)
        })
      );
    }
  }

  function transferProxyAdmin(address contractAddr) internal {
    address proxyAdmin = IProxyLite(contractAddr)._getOwner();
    // if (proxyAdmin != timelockProxy && proxyAdmin == celoGovernance) {
    if (proxyAdmin != celoGovernance && proxyAdmin == timelockProxy) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: contractAddr,
          data: abi.encodeWithSelector(IProxyLite(address(0))._transferOwnership.selector, celoGovernance)
        })
      );
    }
  }
}
