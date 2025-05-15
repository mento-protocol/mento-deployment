// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { MockRedstoneAdapter } from "contracts/MockRedstoneAdapter.sol";

/**
 * Usage: yarn script:dev -n alfajores -s DeployMockRedstoneAdapter
 * Used to deploy mock Redstone Adapters to Alfajores to be used
 * in alfajores to mimic mainnet more closely.
 */
contract DeployMockRedstoneAdapter is Script {
  using Contracts for Contracts.Cache;

  function run() public {
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      MockRedstoneAdapter adapter = new MockRedstoneAdapter();
      adapter.setRateFeeds(_getMainnetRateFeeds(), _getAlfajoresRateFeeds());
      adapter.setSortedOracles(contracts.celoRegistry("SortedOracles"));
    }
    vm.stopBroadcast();
  }

  function _getMainnetRateFeeds() internal pure returns (address[] memory) {
    address[] memory feeds = new address[](7);
    feeds[0] = 0x765DE816845861e75A25fCA122bb6898B8B1282a; // CELO/USD (cUSD address)
    feeds[1] = 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73; // CELO/EUR (cEUR address)
    feeds[2] = 0xe8537a3d056DA446677B9E9d6c5dB704EaAb4787; // CELO/BRL (CBRL address)
    feeds[3] = 0xA1A8003936862E7a15092A91898D69fa8bCE290c; // USDC/USD identifier
    feeds[4] = 0x206B25Ea01E188Ee243131aFdE526bA6E131a016; // USDC/EUR identifier
    feeds[5] = 0x25F21A1f97607Edf6852339fad709728cffb9a9d; // USDC/BRL identifier
    feeds[6] = 0x26076B9702885d475ac8c3dB3Bd9F250Dc5A318B; // EUROC/EUR identifier
    return feeds;
  }

  function _getAlfajoresRateFeeds() internal pure returns (address[] memory) {
    address[] memory feeds = new address[](7);
    feeds[0] = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1; // CELO/USD (cUSD address)
    feeds[1] = 0x10c892A6EC43a53E45D0B916B4b7D383B1b78C0F; // CELO/EUR (cEUR address)
    feeds[2] = 0xE4D517785D091D3c54818832dB6094bcc2744545; // CELO/BRL (CBRL address)
    feeds[3] = 0xA1A8003936862E7a15092A91898D69fa8bCE290c; // USDC/USD identifier
    feeds[4] = 0x206B25Ea01E188Ee243131aFdE526bA6E131a016; // USDC/EUR identifier
    feeds[5] = 0x25F21A1f97607Edf6852339fad709728cffb9a9d; // USDC/BRL identifier
    feeds[6] = 0x26076B9702885d475ac8c3dB3Bd9F250Dc5A318B; // EUROC/EUR identifier
    return feeds;
  }
}
