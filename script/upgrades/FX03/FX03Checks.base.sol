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

import { FixidityLib } from "mento-core-2.3.1/common/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.3.1/interfaces/IBiPoolManager.sol";
import { IBroker } from "mento-core-2.3.1/interfaces/IBroker.sol";
import { IERC20Metadata } from "mento-core-2.3.1/common/interfaces/IERC20Metadata.sol";
import { IRegistry } from "mento-core-2.3.1/common/interfaces/IRegistry.sol";

import { IFeeCurrencyWhitelist } from "script/interfaces/IFeeCurrencyWhitelist.sol";

import { BiPoolManagerProxy } from "mento-core-2.3.1/proxies/BiPoolManagerProxy.sol";
import { StableTokenGHSProxy } from "mento-core-2.6.0/tokens/StableTokenGHSProxy.sol";
import { Broker } from "mento-core-2.3.1/swap/Broker.sol";
import { BiPoolManager } from "mento-core-2.3.1/swap/BiPoolManager.sol";
import { Exchange } from "mento-core-2.3.1/legacy/Exchange.sol";
import { TradingLimits } from "mento-core-2.3.1/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.3.1/oracles/BreakerBox.sol";
import { SortedOracles } from "mento-core-2.3.1/common/SortedOracles.sol";
import { Reserve } from "mento-core-2.3.1/swap/Reserve.sol";
import { MedianDeltaBreaker } from "mento-core-2.3.1/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.3.1/oracles/breakers/ValueDeltaBreaker.sol";
import { ConstantSumPricingModule } from "mento-core-2.3.1/swap/ConstantSumPricingModule.sol";
import { SafeMath } from "celo-foundry/test/SafeMath.sol";
import { Proxy } from "mento-core-2.3.1/common/Proxy.sol";

import { FX03Config, Config } from "./Config.sol";

contract FX03ChecksBase is GovernanceScript, Test {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;
  using SafeMath for uint256;

  address public cUSD;
  address payable public cCHF;
  address payable public cNGN;
  address payable public cJPY;

  address public stableTokenV2;

  address public governance;
  address public medianDeltaBreaker;
  address payable sortedOraclesProxy;
  address public constantSum;
  address payable biPoolManagerProxy;
  address public reserve;
  address public broker;
  address public breakerBox;
  address public validators;

  function setUp() public {
    // Load addresses from deployments
    contracts.load("MU01-00-Create-Proxies"); // BrokerProxy & BiPoolProxy
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts"); // Pricing Modules
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts");
    contracts.load("MU04-00-Create-Implementations"); // First StableTokenV2 deployment

    // TODO: To be created, confirm name and update
    contracts.load("FX02-00-Deploy-Proxys");

    // Get proxy addresses
    cCHF = contracts.deployed("StableTokenCHFProxy");
    cNGN = contracts.deployed("StableTokenNGNProxy");
    cJPY = contracts.deployed("StableTokenJPYProxy");
    stableTokenV2 = contracts.deployed("StableTokenV2");

    cUSD = contracts.celoRegistry("StableToken");
    reserve = contracts.celoRegistry("Reserve");
    broker = contracts.celoRegistry("Broker");
    governance = contracts.celoRegistry("Governance");
    sortedOraclesProxy = address(uint160(contracts.celoRegistry("SortedOracles")));

    // Get Deployment addresses
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    constantSum = contracts.deployed("ConstantSumPricingModule");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");

    validators = contracts.celoRegistry("Validators");
  }
}
