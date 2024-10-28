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

  function _getOwner() external view returns (address);

  function _transferOwnership(address) external;
}

interface IReserveLite {
  function getOtherReserveAddresses() external returns (address[] memory);

  function removeOtherReserveAddress(address, uint256) external returns (bool);

  function addOtherReserveAddress(address) external returns (bool);
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

  // Mento Reserve Multisig address:
  address private reserveMultisig;

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
    PUSOProxy = address(uint160(contracts.deployed("StableTokenPHPProxy")));
    cCOPProxy = address(uint160(contracts.deployed("StableTokenCOPProxy")));

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
    governanceFactory = contracts.deployed("GovernanceFactory");
    timelockProxy = IGovernanceFactory(governanceFactory).governanceTimelock();

    // Mento Reserve Multisig address:
    reserveMultisig = contracts.dependency("PartialReserveMultisig");
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

    proposal_updateOtherReserveAddresses();
    proposal_transferTokenOwnership();
    proposal_transferMentoV2Ownership();
    proposal_transferMentoV1Ownership();
    proposal_transferGovFactoryOwnership();

    return transactions;
  }

  function proposal_updateOtherReserveAddresses() public {
    // remove anchorage addressess
    address[] memory otherReserves = IReserveLite(reserveProxy).getOtherReserveAddresses();
    for (uint256 i = 0; i < otherReserves.length; i++) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: reserveProxy,
          // we remove the first index(0) in the list for each iteration because the index changes after each removal
          data: abi.encodeWithSelector(IReserveLite(0).removeOtherReserveAddress.selector, otherReserves[i], 0)
        })
      );
    }
    // add reserve multisig
    transactions.push(
      ICeloGovernance.Transaction({
        value: 0,
        destination: reserveProxy,
        data: abi.encodeWithSelector(IReserveLite(0).addOtherReserveAddress.selector, reserveMultisig)
      })
    );
  }

  function proposal_transferTokenOwnership() public {
    address[] memory tokenProxies = Arrays.addresses(
      cUSDProxy,
      cEURProxy,
      cBRLProxy,
      eXOFProxy,
      cKESProxy,
      PUSOProxy,
      cCOPProxy
    );
    for (uint i = 0; i < tokenProxies.length; i++) {
      transferOwnership(tokenProxies[i]);
      transferProxyAdmin(tokenProxies[i]);
    }

    // All the token proxies are pointing to the same StableTokenV2 implementation (cUSD)
    // so we only need to transfer ownership of that single contract.
    address sharedImplementation = IProxyLite(cUSDProxy)._getImplementation();
    for (uint i = 0; i < tokenProxies.length; i++) {
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
    if (contractOwner != timelockProxy && contractOwner == celoGovernance) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: contractAddr,
          data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
        })
      );
    }
  }

  function transferProxyAdmin(address contractAddr) internal {
    address proxyAdmin = IProxyLite(contractAddr)._getOwner();
    if (proxyAdmin != timelockProxy && proxyAdmin == celoGovernance) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: contractAddr,
          data: abi.encodeWithSelector(IProxyLite(0)._transferOwnership.selector, timelockProxy)
        })
      );
    }
  }
}
