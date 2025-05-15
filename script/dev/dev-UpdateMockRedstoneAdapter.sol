// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable var-name-mixedcase, const-name-snakecase
pragma solidity ^0.8.18;

import { console2 as console } from "forge-std/Script.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { MockRedstoneAdapter } from "contracts/MockRedstoneAdapter.sol";

interface IRedstoneAdapter {
  struct DataFeedDetails {
    bytes32 dataFeedId;
    address tokenAddress;
  }

  function getDataFeeds() external view returns (DataFeedDetails[] memory);

  function getTimestampsFromLatestUpdate() external view returns (uint128 dataTimestamp, uint128 blockTimestamp);

  function getValueForDataFeed(bytes32 dataFeedId) external view returns (uint256);

  function getValuesForDataFeeds(bytes32[] memory requestedDataFeedIds) external view returns (uint256[] memory);
}

/**
 * Usage: yarn script:dev -n alfajores -s UpdateMockRedstoneAdapter
 * Redstone doesn't report on Alfajores so in order to have as close
 * of a setup as possible between environments we deploy a MockRedstoneAdapter.

 * This script pulls data from the mainnet RedstoneAdapter and updates the
 * mock on Alfajores, and can be run periodically during testing.
 */
contract UpdateMockRedstoneAdapter is Script {
  address public constant MAINNET_REDSTONE_ADAPTER = 0x6490a3FFAD86CA14FF84Be380D5639Fb8fBD311B;
  using Contracts for Contracts.Cache;

  address mockAdapterAddress;

  constructor() Script() {
    if (ChainLib.isAlfajores()) {
      setUp_alfajores();
    } else {
      console.log("This script is only meant to be run on testnets");
    }
  }

  function setUp_alfajores() internal {
    contracts.loadSilent("dev-DeployMockRedstoneAdapter", "latest");
    mockAdapterAddress = contracts.deployed("MockRedstoneAdapter");
  }

  function run() public {
    uint256 celoFork = vm.createFork("celo");
    uint256 testnetFork = vm.createFork(ChainLib.rpcToken());

    vm.selectFork(celoFork);

    IRedstoneAdapter mainnetAdapter = IRedstoneAdapter(0x6490a3FFAD86CA14FF84Be380D5639Fb8fBD311B);
    IRedstoneAdapter.DataFeedDetails[] memory dataFeeds = mainnetAdapter.getDataFeeds();
    uint256[] memory values = mainnetAdapter.getValuesForDataFeeds(getDataFeedsIds(dataFeeds));
    (uint128 dataTimestamp, uint128 blockTimestamp) = mainnetAdapter.getTimestampsFromLatestUpdate();

    vm.selectFork(testnetFork);
    vm.startBroadcast(vm.envUint("MOCK_REDSTONE_PROVIDER_PK"));
    {
      MockRedstoneAdapter mockAdapter = MockRedstoneAdapter(mockAdapterAddress);
      mockAdapter.update(getDataFeedsAddresses(dataFeeds), values, dataTimestamp, blockTimestamp);
      mockAdapter.relay();
    }
    vm.stopBroadcast();

    console.log("Latest data timestamp: %s", dataTimestamp);
    console.log("Latest block timestamp: %s", blockTimestamp);
    console.log("\n");

    for (uint i = 0; i < dataFeeds.length; i++) {
      console.log("Updated mainnet feed %s with value %s", dataFeeds[i].tokenAddress, values[i]);
    }
  }

  function getDataFeedsIds(
    IRedstoneAdapter.DataFeedDetails[] memory dataFeeds
  ) internal pure returns (bytes32[] memory) {
    bytes32[] memory ids = new bytes32[](dataFeeds.length);
    for (uint i = 0; i < dataFeeds.length; i++) {
      ids[i] = dataFeeds[i].dataFeedId;
    }
    return ids;
  }

  function getDataFeedsAddresses(
    IRedstoneAdapter.DataFeedDetails[] memory dataFeeds
  ) internal pure returns (address[] memory) {
    address[] memory addresses = new address[](dataFeeds.length);
    for (uint i = 0; i < dataFeeds.length; i++) {
      addresses[i] = dataFeeds[i].tokenAddress;
    }
    return addresses;
  }
}
