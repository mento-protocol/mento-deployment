// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;
import { Arrays } from "script/utils/Arrays.sol";

import { console2 } from "forge-std/console2.sol";
import { GovernanceScript } from "script/utils/Script.sol";
import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";
import { Config } from "script/utils/Config.sol";

contract ValueDeltaBreakerCfg is GovernanceScript {
  struct ValueDeltaBreakerOverride {
    address rateFeedId;
    uint256 currentThreshold;
    uint256 targetThreshold;
  }

  function valueDeltaBreakerOverrides() public view returns (ValueDeltaBreakerOverride[] memory) {
    ValueDeltaBreakerOverride[] memory overrides = new ValueDeltaBreakerOverride[](2);
    // cUSD/USDC and cUSD/axlUSDC (both use the same rate feed id)
    overrides[0] = ValueDeltaBreakerOverride({
      rateFeedId: toRateFeedId("USDCUSD"),
      currentThreshold: 5000000000000000000000, // 0.005 or 5e21
      targetThreshold: 1000000000000000000000 // 0.001 or 1e21
    });
    // cUSD/USDT
    overrides[1] = ValueDeltaBreakerOverride({
      rateFeedId: toRateFeedId("USDTUSD"),
      currentThreshold: 5000000000000000000000, // 0.005 or 5e21
      targetThreshold: 1000000000000000000000 // 0.001 or 1e21
    });
    return overrides;
  }
}
