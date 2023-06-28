// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { Ownable } from "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import { Proxy } from "mento-core-2.0.0/common/Proxy.sol";


/*
 yarn deploy -n <network> -u MU01 -s MU01-03-Governance-Ownership-Transfer.sol
*/
contract MU01_GovernanceOwnershipTransfer is Script {
  function run() public {
    contracts.load("MU01-00-Create-Proxies", "latest");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU01-02-Create-Implementations", "latest");

    string[4] memory proxies = [
      "BreakerBoxProxy",
      "BiPoolManagerProxy",
      "PartialReserveProxy",
      "BrokerProxy"
    ];
    string[9] memory ownables = [
      "BreakerBox",
      "BiPoolManager",
      "MedianDeltaBreaker",
      "ValueDeltaBreaker",
      "Broker",
      "StableToken",
      "StableTokenEUR",
      "StableTokenBRL",
      "Reserve"
    ];

    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      for (uint256 i = 0; i < proxies.length; i++) {
        address payable proxyAddy = contracts.deployed(proxies[i]);
        Proxy proxy = Proxy(proxyAddy);
        if (proxy._getOwner() != governance) {
          console2.log("%s(%s) ownership transferred to %s", proxies[i], proxyAddy, governance);
          proxy._transferOwnership(governance);
        }
      }

      for (uint256 i = 0; i < ownables.length; i++) {
        address ownableAddy = contracts.deployed(ownables[i]);
        Ownable ownable = Ownable(ownableAddy);
        if (ownable.owner() != governance) {
          console2.log("%s(%s) ownership transferred to %s", ownables[i], ownableAddy, governance);
          ownable.transferOwnership(governance);
        }
      }
    }
    vm.stopBroadcast();
  }
}
