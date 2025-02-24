// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Test, console2 as console } from "forge-std/Test.sol";
import { GovernanceScript } from "script/utils/mento/Script.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IProxyLite {
  function _getImplementation() external view returns (address);

  function _getOwner() external view returns (address);
}

interface IOwnableLite {
  function owner() external view returns (address);
}

contract GDChecksBase is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  address public goodDollarExchangeProviderProxy;
  address public goodDollarExpansionControllerProxy;
  address public goodDollarReserveProxy;
  address public mentoReserveProxy;
  address public brokerProxy;
  address public biPoolManagerProxy;
  address public cUSDProxy;

  address public goodDollarExchangeProviderImplementation;
  address public goodDollarExpansionControllerImplementation;
  address public newBrokerImplementation;
  address public reserveImplementation;

  address public goodDollarAvatar;
  address public goodDollarDistributionHelper;
  address public celoRegistry;
  address public goodDollarToken;
  address public governanceFactory;
  address public timelock;

  function setUp() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest"); // BrokerProxy
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest"); // GovernanceFactory
    contracts.loadSilent("GD-00-Deploy-Implementations", "latest"); // new GD Implementations
    contracts.loadSilent("GD-01-Deploy-Proxies", "latest"); // new GD Proxies

    goodDollarExchangeProviderProxy = contracts.deployed("GoodDollarExchangeProviderProxy");
    //goodDollarExchangeProviderProxy = 0xa82C990D587FfADe7ab91B436269EA0C39a39929;
    goodDollarExpansionControllerProxy = contracts.deployed("GoodDollarExpansionControllerProxy");
    //goodDollarExpansionControllerProxy = 0xF70455bb461724f133794C3BbABad573D8c098a4;
    goodDollarReserveProxy = contracts.deployed("GoodDollarReserveProxy");
    mentoReserveProxy = contracts.celoRegistry("Reserve");
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    cUSDProxy = contracts.celoRegistry("StableToken");

    goodDollarExchangeProviderImplementation = contracts.deployed("GoodDollarExchangeProvider");
    goodDollarExpansionControllerImplementation = contracts.deployed("GoodDollarExpansionController");
    newBrokerImplementation = contracts.deployed("Broker");
    reserveImplementation = IProxyLite(mentoReserveProxy)._getImplementation();

    governanceFactory = contracts.deployed("GovernanceFactory");
    timelock = IGovernanceFactory(governanceFactory).governanceTimelock();
  }
}
