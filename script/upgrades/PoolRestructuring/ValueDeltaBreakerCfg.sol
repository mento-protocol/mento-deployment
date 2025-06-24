// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";

contract ValueDeltaBreakerCfg is GovernanceScript {
  struct Override {
    address rateFeedId;
    uint256 currentThreshold;
    uint256 targetThreshold;
  }

  function valueDeltaBreakerOverrides() public view returns (Override[] memory) {
    Override[] memory overrides = new Override[](2);
    // cUSD/USDC and cUSD/axlUSDC (both use the same rate feed id)
    overrides[0] = Override({
      rateFeedId: toRateFeedId("USDCUSD"),
      currentThreshold: 5000000000000000000000, // 0.005 or 5e21
      targetThreshold: 1000000000000000000000 // 0.001 or 1e21
    });
    // cUSD/USDT
    overrides[1] = Override({
      rateFeedId: toRateFeedId("USDTUSD"),
      currentThreshold: 5000000000000000000000, // 0.005 or 5e21
      targetThreshold: 1000000000000000000000 // 0.001 or 1e21
    });
    return overrides;
  }
}
