// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { FixidityLib } from "mento-core-2.4.0/common/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.4.0/interfaces/IBiPoolManager.sol";
import { IPricingModule } from "mento-core-2.4.0/interfaces/IPricingModule.sol";
import { IReserve } from "mento-core-2.4.0/interfaces/IReserve.sol";
import { IRegistry } from "mento-core-2.4.0/common/interfaces/IRegistry.sol";
import { IFeeCurrencyWhitelist } from "../../interfaces/IFeeCurrencyWhitelist.sol";
import { Proxy } from "mento-core-2.4.0/common/Proxy.sol";
import { IStableTokenV2 } from "mento-core-2.4.0/interfaces/IStableTokenV2.sol";
import { IERC20Metadata } from "mento-core-2.4.0/common/interfaces/IERC20Metadata.sol";

import { Broker } from "mento-core-2.4.0/swap/Broker.sol";
import { TradingLimits } from "mento-core-2.4.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.4.0/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.4.0/oracles/breakers/MedianDeltaBreaker.sol";
import { StableTokenKESProxy } from "mento-core-2.4.0/legacy/proxies/StableTokenKESProxy.sol";

import { MU06Config, Config } from "./Config.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract MU06 is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  ICeloGovernance.Transaction[] private transactions;

  address payable private stableTokenKESProxy;

  address private cUSD;
  address private nativeUSDT;

  address private breakerBox;
  address private valueDeltaBreaker;
  address private brokerProxy;
  address private biPoolManagerProxy;
  address private reserveProxy;

  bool public hasChecks = true;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  /**
   * @dev Loads the deployed contracts from previous deployments
   */
  function loadDeployedContracts() public {
    contracts.load("MU01-00-Create-Proxies", "latest"); // BrokerProxy & BiPoolProxy
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest"); // Value Delta Breaker
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts", "latest"); // BreakerBox & ConstantSumPricingModule
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // Tokens
    cUSD = contracts.celoRegistry("StableToken");
    nativeUSDT = contracts.dependency("NativeUSDT");

    // Oracles
    breakerBox = contracts.deployed("BreakerBox");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");

    // Swaps
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    reserveProxy = contracts.celoRegistry("Reserve");
  }

  function run() public {
    prepare();

    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "SET ME PLS :'(", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    MU06Config.MU06 memory config = MU06Config.get(contracts);

    // Add USDT to the reserve as a collateral asset
    proposal_addUSDTToReserve();

    // Create the exchanges
    proposal_createExchange();

    // Configure the trading limits
    proposal_configureTradingLimits(config);

    // Configure the breaker box
    proposal_configureBreakerBox(config);

    // Configure the value delta breaker
    proposal_configureValueDeltaBreaker(config);
    return transactions;
  }

  function proposal_addUSDTToReserve() private {
    // addCollateralAsset will throw if it's already added
    if (Reserve(reserveProxy).isCollateralAsset(nativeUSDT) == false) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(Reserve(0).addCollateralAsset.selector, nativeUSDT)
        )
      );
    }

    // set EUROC daily spending ratio to 100%
    if (
      Reserve(reserveProxy).getDailySpendingRatioForCollateralAsset(nativeUSDT) !=
      FixidityLib.fixed1().unwrap()
    ) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(
            Reserve(0).setDailySpendingRatioForCollateralAssets.selector,
            Arrays.addresses(nativeUSDT),
            Arrays.uints(FixidityLib.fixed1().unwrap())
          )
        )
      );
    }
  }
}
