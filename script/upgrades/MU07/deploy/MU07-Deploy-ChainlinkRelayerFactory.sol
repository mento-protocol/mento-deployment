// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable contract-name-camelcase
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactory.sol";
import { ChainlinkRelayerFactoryProxy } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactoryProxy.sol";
import { ChainlinkRelayerFactoryProxyAdmin } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactoryProxyAdmin.sol";

contract MU07_Deploy_ChainlinkRelayerFactory is Script {
  using Contracts for Contracts.Cache;

  ChainlinkRelayerFactory private relayerFactory;
  ChainlinkRelayerFactoryProxy private proxy;
  ChainlinkRelayerFactoryProxyAdmin private proxyAdmin;

  function getProxyAdminOwner() internal view returns (address) {
    if (ChainLib.isCelo()) {
      return 0x655133d8E90F8190ed5c1F0f3710F602800C0150; // Mento Labs multisig
    } else {
      return vm.addr(ChainLib.deployerPrivateKey());
    }
  }

  function run() public {
    address proxyAdminOwner = getProxyAdminOwner();
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      relayerFactory = new ChainlinkRelayerFactory(true);
      proxyAdmin = new ChainlinkRelayerFactoryProxyAdmin();
      if (proxyAdmin.owner() != proxyAdminOwner) {
        proxyAdmin.transferOwnership(proxyAdminOwner);
      }
      proxy = new ChainlinkRelayerFactoryProxy(
        address(relayerFactory),
        address(proxyAdmin),
        abi.encodeWithSelector(
          ChainlinkRelayerFactory.initialize.selector,
          contracts.celoRegistry("SortedOracles"),
          vm.addr(ChainLib.deployerPrivateKey())
        )
      );
    }
    console.log("ChainlinkRelayerFactory implementation: ", address(relayerFactory));
    console.log("ChainlinkRelayerFactoryProxy: ", address(proxy));
    console.log("ChainlinkRelayerFactoryProxyAdmin: ", address(proxyAdmin));
    vm.stopBroadcast();
  }
}
