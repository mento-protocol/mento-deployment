// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";
import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";

import { GovernanceScript } from "script/utils/Script.sol";
import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";
import { SafeMath } from "celo-foundry/test/SafeMath.sol";

contract MU06ChecksBase is GovernanceScript, Test {
  using FixidityLib for FixidityLib.Fraction;
  using SafeMath for uint256;

  //tokens
  address public cUSDProxy;
  address public nativeUSDC;
  address public bridgedUSDC;
  address public nativeUSDT;

  //mento contracts
  address public brokerProxy;
  address public biPoolManagerProxy;
  address payable public reserveProxy;
  address public breakerBox;
  address public valueDeltaBreaker;
  address public sortedOraclesProxy;

  address public reserveSpender;

  function setUp() public {
    new PrecompileHandler();

    // Load addresses from deployments
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-02-Create-Implementations", "latest");

    // Tokens
    cUSDProxy = address(uint160(contracts.celoRegistry("StableToken")));
    nativeUSDC = contracts.dependency("NativeUSDC");
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    nativeUSDT = contracts.dependency("NativeUSDT");

    // Mento contracts
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    reserveProxy = address(uint160(contracts.celoRegistry("Reserve")));
    breakerBox = contracts.deployed("BreakerBox");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
    sortedOraclesProxy = contracts.celoRegistry("SortedOracles");

    reserveSpender = contracts.dependency("PartialReserveMultisig");
  }
}
