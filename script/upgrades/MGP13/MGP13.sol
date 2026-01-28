// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { console2 as console } from "forge-std/Script.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

import { IBiPoolManager, FixidityLib } from "mento-core-2.6.5/interfaces/IBiPoolManager.sol";
import { IProxy } from "mento-core-2.5.0/common/interfaces/IProxy.sol";

import { MGP13Config } from "./Config.sol";

contract MGP13 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  MGP13Config private config;
  ICeloGovernance.Transaction[] private transactions;

  bool public hasChecks = true;

  function prepare() public {
    config = new MGP13Config();
    config.load();
  }

  function run() public {
    prepare();

    IGovernanceFactory governanceFactory = IGovernanceFactory(ChainLib.governanceFactory());
    address mentoGovernor = governanceFactory.mentoGovernor();

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      createStructuredProposal(
        "MGP-13: Update spreads for selected pools",
        "./script/upgrades/MGP13/MGP13.md",
        _transactions,
        mentoGovernor
      );
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    console.log("==========================================");
    console.log(unicode"🤖 Building proposal for MGP-13");

    // address biPoolManagerProxy = config.biPoolManagerProxy();
    // address originalBiPoolManagerImpl = config.biPoolManagerImpl();
    // address tmpBiPoolManagerImpl = config.tmpBiPoolManagerImpl();
    // address currentBiPoolManagerImpl = IProxy(biPoolManagerProxy)._getImplementation();

    // require(originalBiPoolManagerImpl != address(0), "Original BiPoolManager impl is 0");
    // require(tmpBiPoolManagerImpl != address(0), "Temporary BiPoolManager impl is 0");
    // require(currentBiPoolManagerImpl != address(0), "Current BiPoolManager impl is 0");
    // require(currentBiPoolManagerImpl == originalBiPoolManagerImpl, "Current BiPoolManager impl mismatch");

    updateBiPoolManagerImpl();
    updateSpreads();
    rollbackBiPoolManagerImpl();

    console.log("==========================================");
    return transactions;
  }

  function updateBiPoolManagerImpl() internal {
    address biPoolManagerProxy = config.biPoolManagerProxy();

    require(
      IProxy(biPoolManagerProxy)._getImplementation() == config.currentBiPoolManagerImpl(),
      "Current BiPoolManager impl mismatch"
    );

    console.log(unicode"🤖 Updating BiPoolManager impl to:", config.tmpBiPoolManagerImpl());

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxy,
        abi.encodeWithSelector(IProxy._setImplementation.selector, config.tmpBiPoolManagerImpl())
      )
    );
  }

  function updateSpreads() internal {
    MGP13Config.SpreadOverride[] memory overrides = config.spreadOverrides();
    require(overrides.length > 0, "No spread overrides configured");

    address biPoolManagerProxy = config.biPoolManagerProxy();
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);

    for (uint256 i = 0; i < overrides.length; i++) {
      MGP13Config.SpreadOverride memory overrideConfig = overrides[i];
      IBiPoolManager.PoolExchange memory exchange = biPoolManager.getPoolExchange(overrideConfig.exchangeId);

      require(exchange.asset0 == overrideConfig.asset0, "asset0 mismatch on spread override");
      require(exchange.asset1 == overrideConfig.asset1, "asset1 mismatch on spread override");
      require(
        FixidityLib.equals(exchange.config.spread, overrideConfig.currentSpread),
        "current spread mismatch on spread override"
      );

      console.log(unicode"🤖 Updating spread for", overrideConfig.name);

      transactions.push(
        ICeloGovernance.Transaction(
          0,
          biPoolManagerProxy,
          abi.encodeWithSelector(
            IBiPoolManager.setSpread.selector,
            overrideConfig.exchangeId,
            FixidityLib.unwrap(overrideConfig.newSpread)
          )
        )
      );
    }
  }

  function rollbackBiPoolManagerImpl() internal {
    // require(
    //   IProxy(config.biPoolManagerProxy())._getImplementation() == config.tmpBiPoolManagerImpl(),
    //   "Temporary BiPoolManager impl mismatch"
    // );

    console.log(unicode"🤖 Rolling back BiPoolManager impl to:", config.currentBiPoolManagerImpl());

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        config.biPoolManagerProxy(),
        abi.encodeWithSelector(IProxy._setImplementation.selector, config.currentBiPoolManagerImpl())
      )
    );
  }
}
