// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable contract-name-camelcase
pragma solidity ^0.8.18;

import { Script } from "script/utils/mento/Script.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { console2 } from "forge-std/Script.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { Broker } from "mento-core-2.6.0/swap/Broker.sol";
import { GoodDollarExchangeProvider } from "mento-core-2.6.0/goodDollar/GoodDollarExchangeProvider.sol";
import { GoodDollarExpansionController } from "mento-core-2.6.0/goodDollar/GoodDollarExpansionController.sol";

interface IOwnableLite {
  function transferOwnership(address newOwner) external;

  function owner() external view returns (address);
}

contract GD_00_Deploy_Implementations is Script {
  using Contracts for Contracts.Cache;

  address public brokerImplementation;
  address public exchangeProviderImplementation;
  address public expansionControllerImplementation;

  address public governanceFactory;
  address public timelockProxy;

  function run() public {
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");
    governanceFactory = contracts.deployed("GovernanceFactory");
    require(governanceFactory != address(0), "GovernanceFactory not found");

    timelockProxy = IGovernanceFactory(governanceFactory).governanceTimelock();
    require(timelockProxy != address(0), "TimelockProxy not found");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      brokerImplementation = address(new Broker(false));
      IOwnableLite(brokerImplementation).transferOwnership(timelockProxy);
      exchangeProviderImplementation = address(new GoodDollarExchangeProvider(true));
      expansionControllerImplementation = address(new GoodDollarExpansionController(true));
    }
    vm.stopBroadcast();

    console2.log("brokerImplementation", brokerImplementation);
    console2.log("exchangeProviderImplementation", exchangeProviderImplementation);
    console2.log("expansionControllerImplementation", expansionControllerImplementation);
  }
}
