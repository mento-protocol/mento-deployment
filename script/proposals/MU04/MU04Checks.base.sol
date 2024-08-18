// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std-prev/Test.sol";
import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";

import { GovernanceScript } from "script/utils/v1/Script.sol";
import { Chain } from "script/utils/v1/Chain.sol";
import { Arrays } from "script/utils/v1/Arrays.sol";
import { Proxy } from "mento-core-2.2.0/common/Proxy.sol";
import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";
import { SafeMath } from "celo-foundry/test/SafeMath.sol";

contract MU04ChecksBase is GovernanceScript, Test {
  using FixidityLib for FixidityLib.Fraction;
  using SafeMath for uint256;

  // Tokens
  address public stableTokenV2;
  address public celoToken;
  address public cUSDProxy;
  address public cEURProxy;
  address public cBRLProxy;
  address payable public eXOFProxy;
  address public bridgedUSDC;
  address public bridgedEUROC;

  // other contracts
  address public brokerProxy;
  address payable public biPoolManagerProxy;
  address payable public reserveProxy;
  address payable public partialReserveProxy;
  address public breakerBox;
  address public sortedOraclesProxy;

  address public grandaMentoProxy;
  address public exchangeProxy;
  address public exchangeEURProxy;
  address public exchangeBRLProxy;

  address public oldMainReserveMultisig;
  address public partialReserveMultisig;
  address public newReserveImplementation;

  address public freezerProxy;
  address public validators;
  address public governance;

  function setUp() public {
    new PrecompileHandler();

    // Load addresses from deployments
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("MU04-00-Create-Implementations", "latest");

    // tokens
    stableTokenV2 = contracts.deployed("StableTokenV2");
    cUSDProxy = address(uint160(contracts.celoRegistry("StableToken")));
    cEURProxy = address(uint160(contracts.celoRegistry("StableTokenEUR")));
    cBRLProxy = address(uint160(contracts.celoRegistry("StableTokenBRL")));
    eXOFProxy = address(uint160(contracts.celoRegistry("StableTokenXOF")));
    celoToken = contracts.celoRegistry("GoldToken");
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    bridgedEUROC = contracts.dependency("BridgedEUROC");

    // other contracts
    brokerProxy = contracts.celoRegistry("Broker");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    reserveProxy = address(uint160(contracts.celoRegistry("Reserve")));
    partialReserveProxy = address(uint160(contracts.deployed("PartialReserveProxy")));
    breakerBox = contracts.deployed("BreakerBox");
    sortedOraclesProxy = contracts.celoRegistry("SortedOracles");

    grandaMentoProxy = contracts.dependency("GrandaMento");
    exchangeProxy = contracts.dependency("Exchange");
    exchangeEURProxy = contracts.dependency("ExchangeEUR");
    exchangeBRLProxy = contracts.dependency("ExchangeBRL");

    oldMainReserveMultisig = 0x554Fca0f7c465cd2F8C305a10bF907A2034d2a19;
    partialReserveMultisig = contracts.dependency("PartialReserveMultisig");
    newReserveImplementation = Proxy(partialReserveProxy)._getImplementation();

    governance = contracts.celoRegistry("Governance");
    validators = contracts.celoRegistry("Validators");
    freezerProxy = contracts.celoRegistry("Freezer");
  }
}
