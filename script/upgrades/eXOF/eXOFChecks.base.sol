// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import { GovernanceScript } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";
import { IBroker } from "mento-core-2.2.0/interfaces/IBroker.sol";
import { IERC20Metadata } from "mento-core-2.2.0/common/interfaces/IERC20Metadata.sol";
import { IRegistry } from "mento-core-2.2.0/common/interfaces/IRegistry.sol";

import { IFeeCurrencyWhitelist } from "script/interfaces/IFeeCurrencyWhitelist.sol";

import { BiPoolManagerProxy } from "mento-core-2.2.0/proxies/BiPoolManagerProxy.sol";
import { StableTokenXOFProxy } from "mento-core-2.2.0/legacy/proxies/StableTokenXOFProxy.sol";
import { StableTokenXOF } from "mento-core-2.2.0/legacy/StableTokenXOF.sol";
import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { Exchange } from "mento-core-2.2.0/legacy/Exchange.sol";
import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";
import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";
import { Reserve } from "mento-core-2.2.0/swap/Reserve.sol";
import { MedianDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/ValueDeltaBreaker.sol";
import { ConstantSumPricingModule } from "mento-core-2.2.0/swap/ConstantSumPricingModule.sol";
import { SafeMath } from "celo-foundry/test/SafeMath.sol";
import { Proxy } from "mento-core-2.2.0/common/Proxy.sol";

import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";

import { eXOFConfig, Config } from "./Config.sol";

contract eXOFChecksBase is GovernanceScript, Test {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;
  using SafeMath for uint256;

  address public celoToken;
  address public cUSD;
  address public cEUR;
  address public cBRL;
  address payable public eXOF;
  address public bridgedUSDC;
  address public bridgedEUROC;
  address public governance;
  address public medianDeltaBreaker;
  address public valueDeltaBreaker;
  address public nonrecoverableValueDeltaBreaker;
  address public biPoolManager;
  address payable sortedOraclesProxy;
  address public sortedOracles;
  address public constantSum;
  address public constantProduct;
  address payable biPoolManagerProxy;
  address public partialReserve;
  address public reserve;
  address public broker;
  address public breakerBox;

  function setUp() public {
    new PrecompileHandler(); // needed for reserve CELO transfer checks
    // Load addresses from deployments
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-02-Create-Implementations", "latest");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("eXOF-01-Create-Implementations", "latest");

    // Get proxy addresses
    eXOF = contracts.deployed("StableTokenXOFProxy");
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    cBRL = contracts.celoRegistry("StableTokenBRL");
    partialReserve = contracts.deployed("PartialReserveProxy");
    reserve = contracts.celoRegistry("Reserve");
    celoToken = contracts.celoRegistry("GoldToken");
    broker = contracts.celoRegistry("Broker");
    governance = contracts.celoRegistry("Governance");
    sortedOraclesProxy = address(uint160(contracts.celoRegistry("SortedOracles")));

    // Get Deployment addresses
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    bridgedEUROC = contracts.dependency("BridgedEUROC");
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
    biPoolManager = contracts.deployed("BiPoolManager");
    constantSum = contracts.deployed("ConstantSumPricingModule");
    constantProduct = contracts.deployed("ConstantProductPricingModule");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    sortedOracles = contracts.deployed("SortedOracles");
  }
}
