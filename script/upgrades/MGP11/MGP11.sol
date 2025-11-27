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

import { MGP11Config } from "./Config.sol";

import { StableTokenV2Renamer } from "contracts/StableTokenV2Renamer.sol";

// interface IStableTokenV2Renamer {
//   function setSymbol(string calldata newSymbol) external;
// }

/**
 * @notice This script is use to create the proposal containing the CELO
 *         governance transactions needed to update the cGHS token name
 * @dev depends on: ../deploy/*.sol
 */
contract MGP11 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  address private stableTokenV2ImplementationAddress;
  address private renamerImplAddress;

  MGP11Config private config;

  ICeloGovernance.Transaction[] private transactions;

  bool public hasChecks = true;

  string private constant GHS_NAME = "Celo Ghanaian Cedi";

  function prepare() public {
    setAddresses();
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    config = new MGP11Config();
    config.load();

    stableTokenV2ImplementationAddress = stableTokenV2ImplAddress();
    renamerImplAddress = renamerImplementationAddress();
  }

  function run() public {
    prepare();

    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      createProposal(_transactions, "TODO: Add MD, update to structured proposal", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    console.log("========= Pre-upgrade state =========");
    config.printAllStables();

    address[] memory stables = config.getStables();
    for (uint256 i = 0; i < stables.length; i++) {
      address stable = stables[i];
      // console.log("Renaming %s (%s)", IERC20Lite(stable).symbol(), stable);
      renameToken(stable);
    }

    return transactions;
  }

  function renameToken(address token) public {
    MGP11Config.TokenRenamingTask memory task = config.getTask(token);

    require(IProxy(token)._getImplementation() == stableTokenV2ImplementationAddress, "Current impl != expected impl");
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        token,
        abi.encodeWithSelector(IProxy._setImplementation.selector, renamerImplAddress)
      )
    );

    require(equal(task.oldSymbol, IERC20Lite(token).symbol()), "Current symbol != expected old symbol");
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        token,
        abi.encodeWithSelector(StableTokenV2Renamer.setSymbol.selector, task.newSymbol)
      )
    );

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        token,
        abi.encodeWithSelector(IProxy._setImplementation.selector, stableTokenV2ImplementationAddress)
      )
    );
  }

  function stableTokenV2ImplAddress() internal returns (address) {
    if (ChainLib.isSepolia()) {
      return contracts.dependency("StableTokenV2Implementation");
    }

    if (ChainLib.isCelo()) {
      contracts.loadSilent("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment
      return contracts.deployed("StableTokenV2");
    }

    revert("Unexpected network for MGP11");
  }

  function renamerImplementationAddress() internal returns (address) {
    contracts.loadSilent("MGP11-00-Rename-Implementation", "latest");
    return contracts.deployed("StableTokenV2Renamer");
  }

  function equal(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
  }
}
