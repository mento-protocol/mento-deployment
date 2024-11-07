// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable contract-name-camelcase
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { ProxyDeployerLib } from "mento-core-2.5.0/governance/deployers/ProxyDeployerLib.sol";

interface IOwnableLite {
    function transferOwnership(address newOwner) external;
}

contract MU09_Deploy_LockingProxyAdmin is Script {
  using Contracts for Contracts.Cache;

  function run() public { 
    address mentoLabsMultisig = contracts.dependency("MentoLabsMultisig");
    require(mentoLabsMultisig != address(0), "MentoLabsMultisig address not found");

    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      // Check out the name of the contract in the contracts cache. Could clash with other contracts
      IOwnableLite proxyAdmin = IOwnableLite(address(ProxyDeployerLib.deployAdmin()));
      console.log("Deployed ProxyAdmin for Locking at: %s", address(proxyAdmin));

      proxyAdmin.transferOwnership(mentoLabsMultisig);
      console.log("Transferred LockingProxyAdmin ownership to MentoLabsMultisig: %s", mentoLabsMultisig);
    }
    vm.stopBroadcast();
  }
}
