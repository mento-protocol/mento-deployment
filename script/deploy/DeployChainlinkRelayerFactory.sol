// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-develop/oracles/ChainlinkRelayerFactory.sol";
import { ChainlinkRelayerFactoryProxy } from "mento-core-develop/oracles/ChainlinkRelayerFactoryProxy.sol";
import { ChainlinkRelayerFactoryProxyAdmin } from "mento-core-develop/oracles/ChainlinkRelayerFactoryProxyAdmin.sol";

contract DeployChainlinkRelayerFactory is Script {
  using Contracts for Contracts.Cache;

  ChainlinkRelayerFactory relayerFactory;
  ChainlinkRelayerFactoryProxy proxy;
  ChainlinkRelayerFactoryProxyAdmin proxyAdmin;

  function getProxyAdminOwner() internal returns (address) {
    if (Chain.isCelo()) {
      return 0x655133d8E90F8190ed5c1F0f3710F602800C0150;
    } else {
      return vm.addr(Chain.deployerPrivateKey());
    }
  }

  function run() public {
    address proxyAdminOwner = getProxyAdminOwner();
    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      relayerFactory = new ChainlinkRelayerFactory(true);
      proxyAdmin = new ChainlinkRelayerFactoryProxyAdmin();
      if (proxyAdmin.owner() != proxyAdminOwner) {
        proxyAdmin.transferOwnership(proxyAdminOwner);
      }
      proxy = new ChainlinkRelayerFactoryProxy(
        address(relayerFactory),
        address(proxyAdmin),
        abi.encodeWithSelector(ChainlinkRelayerFactory.initialize.selector, contracts.celoRegistry("SortedOracles"))
      );
    }
    console.log("ChainlinkRelayerFactory implementation: ", address(relayerFactory));
    console.log("ChainlinkRelayerFactoryProxy: ", address(proxy));
    console.log("ChainlinkRelayerFactoryProxyAdmin: ", address(proxyAdmin));
    vm.stopBroadcast();
  }
}
