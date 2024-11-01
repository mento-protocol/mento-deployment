// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity >=0.5.13 <0.9.0;
// pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

import { IBreakerBox } from "mento-core-2.6.0/interfaces/IBreakerBox.sol";
import { IBiPoolManager } from "mento-core-2.6.0/interfaces/IBiPoolManager.sol";

interface IOwnableLite {
  function owner() external view returns (address);

  function transferOwnership(address recipient) external;
}

interface IProxyLite {
  function _setImplementation(address implementation) external;

  function _getImplementation() external view returns (address);

  function _getOwner() external view returns (address);

  function _transferOwnership(address) external;
}

// interface IBiPoolManagerLite {
//   function destroyExchange(bytes32 exchangeId, uint256 index) external;
// }

contract MU09 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;
  // using FixidityLib for FixidityLib.Fraction;

  bool public hasChecks = false;
  ICeloGovernance.Transaction[] private transactions;

  // New implementations:
  address private newBrokerImplementation;
  address private newBiPoolManagerImplementation;
  address private newStableTokenV2Implementation;
  address private newReserveImplementation;

  // Celo Governance:
  address private celoGovernance;

  address private mentoGovernor;

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

    contracts.loadSilent("MU09-00-Create-Implementations", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
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
    mentoGovernor = IGovernanceFactory(governanceFactory).mentoGovernor();
  }

  function run() public {
    prepare();

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "https://TODO", mentoGovernor);
    }
    vm.stopBroadcast();
  }

  function preStateCheck() public {
    // ====== Check all the current implementation addresses =====
    require(
      IProxyLite(brokerProxy)._getImplementation() == 0xA0248A242A1eAca1A0b0513E82246Faa68d3d87C,
      "Unexpected broker impl"
    );
    require(
      IProxyLite(biPoolManagerProxy)._getImplementation() == 0x203c4dD52957405F8F86C40996e9b5b3bF5a6c95,
      "Unexpected bipoolmanager impl"
    );
    require(
      IProxyLite(reserveProxy)._getImplementation() == 0x5B4B6ba128c7BA51d63eD7474A7b17492Fb28476,
      "Unexpected reserve impl"
    );
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
      require(
        IProxyLite(tokenProxies[i])._getImplementation() == 0x3Bd899048f4f6951fFeB5474205B79FDB09D6212,
        "Unexpected stable token impl"
      );
    }

    // ===== Check that  there are currently 16 exchanges before destroying cCOP/cUSD =====
    uint256 PRE_EXISTING_POOLS = 16;
    bytes32[] memory exchanges = IBiPoolManager(biPoolManagerProxy).getExchangeIds();
    require(exchanges.length == PRE_EXISTING_POOLS, "Number of expected pools does not match.");

    // ===== Check that COP/USD is enabled on Breakerbox =====
    address COPUSDFeed = toRateFeedId("relayed:COPUSD");
    address[] memory enabledFeeds = IBreakerBox(breakerBox).getRateFeeds();
    bool found = false;
    for (uint i = 0; i < enabledFeeds.length; i++) {
      found = false || enabledFeeds[i] == COPUSDFeed;
    }
    require(found, "COP/USD feed not enabled on BreakerBox");
    require(IBreakerBox(breakerBox).getRateFeedTradingMode(COPUSDFeed) == 0, "COP/USD feed not enabled for trading");

    console.log("[OK]: Pre-state checks passed\n");
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    preStateCheck();

    proposal_updateImplementations();
    proposal_destroyCOPExchange();
    disableFeedInBreakerBox();

    return transactions;
  }

  function proposal_updateImplementations() public {
    // Broker
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxy,
        abi.encodeWithSelector(IProxyLite(address(0))._setImplementation.selector, newBrokerImplementation)
      )
    );

    // BiPoolManager
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxy,
        abi.encodeWithSelector(IProxyLite(address(0))._setImplementation.selector, newBiPoolManagerImplementation)
      )
    );

    // Reserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        reserveProxy,
        abi.encodeWithSelector(IProxyLite(address(0))._setImplementation.selector, newReserveImplementation)
      )
    );

    // All stable tokens
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
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          tokenProxies[i],
          abi.encodeWithSelector(IProxyLite(address(0))._setImplementation.selector, newStableTokenV2Implementation)
        )
      );
    }
  }

  // Destroy the current cCOP/cUSD exchange
  function proposal_destroyCOPExchange() public {
    // cCOPConfig.cCOP memory config = cCOPConfig.get(contracts);
    bytes32 cCOPcUSDExchangeId = getExchangeId(
      cUSDProxy,
      cCOPProxy,
      true
      // config.poolConfig.asset0,
      // config.poolConfig.asset1,
      // config.poolConfig.isConstantSum
    );

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxy,
        //it's ok to hardcode the index here since the transaction would fail if index and identifier don't match
        abi.encodeWithSelector(IBiPoolManager(address(0)).destroyExchange.selector, cCOPcUSDExchangeId, 15)
      )
    );
  }

  function disableFeedInBreakerBox() public {
    address COPUSDFeed = toRateFeedId("relayed:COPUSD");

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        breakerBox,
        abi.encodeWithSelector(IBreakerBox(address(0)).removeRateFeed.selector, COPUSDFeed)
      )
    );
  }
}
