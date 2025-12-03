// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { IERC20Lite } from "script/interfaces/IERC20Lite.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";
import { IProxy } from "mento-core-2.5.0/common/interfaces/IProxy.sol";

import { MGP12Config } from "./Config.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IStableTokenV2Renamer {
  function setName(string calldata newName) external;

  function setSymbol(string calldata newSymbol) external;
}

contract MGP12 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  MGP12Config private config;

  ICeloGovernance.Transaction[] private transactions;

  bool public hasChecks = true;

  function prepare() public {
    config = new MGP12Config();
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
        "MGP-12: Mento Stablecoins Rebranding",
        "./script/upgrades/MGP12/MGP12.md",
        _transactions,
        mentoGovernor
      );
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    console.log("========= Pre-upgrade state =========\n");
    config.printAllStables();
    console.log("\n");

    address[] memory stables = config.getStables();
    require(stables.length == config.NUM_STABLES(), "Number of stables != expected number of stables");
    for (uint256 i = 0; i < stables.length; i++) {
      address stable = stables[i];
      renameToken(stable);
    }

    return transactions;
  }

  /**
   * @dev Renames the token to the new name and symbol, in four steps:
   *      1. Switch to the temporary renamer implementation
   *      2. Update the name
   *      3. Update the symbol
   *      4. Switch back to the previous StableTokenV2 implementation
   * @param token The address of the token to rename
   */
  function renameToken(address token) public {
    MGP12Config.TokenRenamingTask memory task = config.getTask(token);

    require(
      IProxy(token)._getImplementation() == config.getStableTokenV2ImplAddress(),
      "Current impl != expected impl"
    );
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        token,
        abi.encodeWithSelector(IProxy._setImplementation.selector, config.getRenamerImplAddress())
      )
    );

    require(equal(task.oldName, IERC20Lite(token).name()), "Current name != expected old name");
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        token,
        abi.encodeWithSelector(IStableTokenV2Renamer.setName.selector, task.newName)
      )
    );

    require(equal(task.oldSymbol, IERC20Lite(token).symbol()), "Current symbol != expected old symbol");
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        token,
        abi.encodeWithSelector(IStableTokenV2Renamer.setSymbol.selector, task.newSymbol)
      )
    );

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        token,
        abi.encodeWithSelector(IProxy._setImplementation.selector, config.getStableTokenV2ImplAddress())
      )
    );
  }

  function equal(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
  }
}
