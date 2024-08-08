// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-develop/oracles/ChainlinkRelayerFactory.sol";
import { ChainlinkRelayerFactoryProxy } from "mento-core-develop/oracles/ChainlinkRelayerFactoryProxy.sol";
import { ChainlinkRelayerFactoryProxyAdmin } from "mento-core-develop/oracles/ChainlinkRelayerFactoryProxyAdmin.sol";
import { IChainlinkRelayer } from "mento-core-develop/interfaces/IChainlinkRelayer.sol";

import { ICeloGovernance } from "../interfaces/ICeloGovernance.sol";

interface ISortedOracles {
  function getOracles(address rateFeed) external returns (address[] memory);
}

// TODO: Turn this into a GovernanceScript after upgrading all utils contracts to 0.8.18
contract WhitelistRelayers is Script {
  using Contracts for Contracts.Cache;

  // DEVS: Always set this to the most recent proposal github link before running in prod
  string DESCRIPTION_URL = "whitelist-relayers";

  struct SerializedTransactions {
    uint256[] values;
    address[] destinations;
    bytes data;
    uint256[] dataLengths;
  }

  ChainlinkRelayerFactory relayerFactory;

  constructor() Script() {
    contracts.load("ChainlinkRelayerFactory", "checkpoint");
    relayerFactory = ChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
  }

  ICeloGovernance.Transaction[] transactions;

  function run() public {
    ISortedOracles sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    address[] memory relayers = relayerFactory.getRelayers();
    for (uint i = 0; i < relayers.length; i++) {
      address rateFeedId = IChainlinkRelayer(relayers[i]).rateFeedId();
      address[] memory oracles = sortedOracles.getOracles(rateFeedId);
      bool isOracle = false;
      for (uint j = 0; j < oracles.length; j++) {
        isOracle = isOracle || (oracles[j] == relayers[i]);
      }
      if (!isOracle) {
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: contracts.celoRegistry("SortedOracles"),
            data: abi.encodeWithSignature("addOracle(address,address)", rateFeedId, relayers[i])
          })
        );
      }
    }

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // CELOUSD_relayer.relay();
      createProposal(DESCRIPTION_URL, contracts.celoRegistry("Governance"));
    }
    vm.stopBroadcast();
  }

  function createProposal(string memory descriptionURL, address governance) internal {
    if (Chain.isCelo()) {
      verifyDescription(descriptionURL);
    }
    // Serialize transactions
    SerializedTransactions memory serTxs = serializeTransactions();

    uint256 depositAmount = ICeloGovernance(governance).minDeposit();
    console.log("Celo governance proposal required deposit amount: ", depositAmount);

    // Submit proposal
    // solhint-disable-next-line avoid-call-value,avoid-low-level-calls
    (bool success, bytes memory returnData) = address(governance).call{ value: depositAmount }(
      abi.encodeWithSelector(
        ICeloGovernance.propose.selector,
        serTxs.values,
        serTxs.destinations,
        serTxs.data,
        serTxs.dataLengths,
        descriptionURL
      )
    );

    if (success == false) {
      console.logBytes(returnData);
      revert("Failed to create proposal");
    }
    console.log("Proposal was successfully created. ID: ", abi.decode(returnData, (uint256)));
  }

  function serializeTransactions() internal view returns (SerializedTransactions memory serTxs) {
    serTxs.values = new uint256[](transactions.length);
    serTxs.destinations = new address[](transactions.length);
    serTxs.dataLengths = new uint256[](transactions.length);

    for (uint256 i = 0; i < transactions.length; i++) {
      serTxs.values[i] = transactions[i].value;
      serTxs.destinations[i] = transactions[i].destination;
      serTxs.data = abi.encodePacked(serTxs.data, transactions[i].data);
      serTxs.dataLengths[i] = transactions[i].data.length;
    }
  }

  function verifyDescription(string memory descriptionURL) internal pure {
    bytes memory descriptionPrefix = new bytes(8);
    require(bytes(descriptionURL).length > 8, "Description URL must start with https://");
    for (uint i = 0; i < 8; i++) {
      descriptionPrefix[i] = bytes(descriptionURL)[i];
    }

    require(keccak256(descriptionPrefix) == keccak256("https://"), "Description URL must start with https://");
  }
}
