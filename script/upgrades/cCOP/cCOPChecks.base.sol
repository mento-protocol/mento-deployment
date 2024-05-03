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

import { FixidityLib } from "mento-core-2.4.0/common/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.4.0/interfaces/IBiPoolManager.sol";
import { IBroker } from "mento-core-2.4.0/interfaces/IBroker.sol";
import { IERC20Metadata } from "mento-core-2.4.0/common/interfaces/IERC20Metadata.sol";
import { IRegistry } from "mento-core-2.4.0/common/interfaces/IRegistry.sol";

import { IFeeCurrencyWhitelist } from "script/interfaces/IFeeCurrencyWhitelist.sol";

import { BiPoolManagerProxy } from "mento-core-2.4.0/proxies/BiPoolManagerProxy.sol";
import { StableTokenCOPProxy } from "mento-core-2.4.0/legacy/proxies/StableTokenCOPProxy.sol";
import { Broker } from "mento-core-2.4.0/swap/Broker.sol";
import { BiPoolManager } from "mento-core-2.4.0/swap/BiPoolManager.sol";
import { Exchange } from "mento-core-2.4.0/legacy/Exchange.sol";
import { TradingLimits } from "mento-core-2.4.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.4.0/oracles/BreakerBox.sol";
import { SortedOracles } from "mento-core-2.4.0/common/SortedOracles.sol";
import { Reserve } from "mento-core-2.4.0/swap/Reserve.sol";
import { MedianDeltaBreaker } from "mento-core-2.4.0/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.4.0/oracles/breakers/ValueDeltaBreaker.sol";
import { ConstantSumPricingModule } from "mento-core-2.4.0/swap/ConstantSumPricingModule.sol";
import { SafeMath } from "celo-foundry/test/SafeMath.sol";
import { Proxy } from "mento-core-2.4.0/common/Proxy.sol";

import { cCOPConfig, Config } from "./Config.sol";

contract cCOPChecksBase is GovernanceScript, Test {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;
  using SafeMath for uint256;

  address public cUSD;
  address payable public cCOP;
  address public governance;
  address public medianDeltaBreaker;
  address payable sortedOraclesProxy;
  address public constantProduct;
  address payable biPoolManagerProxy;
  address public reserve;
  address public broker;
  address public breakerBox;

  function setUp() public {
    // Load addresses from deployments
    contracts.loadSilent("MU01-00-Create-Proxies", "latest"); // BrokerProxy & BiPoolProxy
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment
    contracts.loadSilent("cCOP-00-Create-Proxies", "latest");

    // Get proxy addresses
    cCOP = contracts.deployed("StableTokenCOPProxy");
    cUSD = contracts.celoRegistry("StableToken");
    reserve = contracts.celoRegistry("Reserve");
    broker = contracts.celoRegistry("Broker");
    governance = contracts.celoRegistry("Governance");
    sortedOraclesProxy = address(uint160(contracts.celoRegistry("SortedOracles")));

    // Get Deployment addresses
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    constantProduct = contracts.deployed("ConstantProductPricingModule");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
  }
}
