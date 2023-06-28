// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { GovernanceScript } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";
import { ICeloGovernance } from "script/interfaces/ICeloGovernance.sol";

import { IERC20Metadata } from "mento-core-2.0.0/common/interfaces/IERC20Metadata.sol";
import { Reserve } from "mento-core-2.0.0/Reserve.sol";

contract AddOtherReserveAddress is GovernanceScript {
  // TODO: Change this when running
  address constant private oldPartialReserveAddress = 0xAC7cf1c3c13C91b5fCE10090CE0D518853BC49C2;
  ICeloGovernance.Transaction[] private transactions;

  function run() public {
    address governance = contracts.celoRegistry("Governance");

    contracts.loadUpgrade("MU01");
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        address(oldPartialReserveAddress),
        abi.encodeWithSelector(
          Reserve(0).addOtherReserveAddress.selector,
          contracts.deployed("PartialReserveProxy")
        )
      )
    );

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(transactions, "AddOtherReserveAddress", governance);
    }
    vm.stopBroadcast();
  }
}
