// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

library NewPoolsConfig {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct NewPools {
    Config.Pool cUSDcEUR;
    Config.Pool cUSDcREAL;
    Config.Pool cUSDeXOF;
    Config.RateFeed[] rateFeedsConfig;
    Config.Pool[] pools;
  }

  function get(Contracts.Cache storage contracts) internal returns (NewPools memory config) {
    config.pools = new Config.Pool[](3);
    config.pools[0] = config.cUSDcEUR = cUSDcEUR_PoolConfig(contracts);
    config.pools[1] = config.cUSDcREAL = cUSDcREAL_PoolConfig(contracts);
    config.pools[2] = config.cUSDeXOF = cUSDeXOF_PoolConfig(contracts);

    config.rateFeedsConfig = newPoolsRateFeedConfig();
  }

  function newPoolsRateFeedConfig() internal pure returns (Config.RateFeed[] memory rateFeedConfig) {
    address[] memory rateFeedIDs = new address[](3);
    rateFeedIDs[0] = Config.rateFeedID("relayed:EURUSD");
    rateFeedIDs[1] = Config.rateFeedID("relayed:BRLUSD");
    rateFeedIDs[2] = Config.rateFeedID("relayed:XOFUSD");

    Config.RateFeed[] memory rateFeedsConfig = new Config.RateFeed[](3);
    for (uint256 i = 0; i < rateFeedIDs.length; i++) {
      Config.RateFeed memory cfg;
      cfg.rateFeedID = rateFeedIDs[i];
      cfg.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
        enabled: true,
        threshold: FixidityLib.newFixedFraction(4, 100), // 4%
        cooldown: 15 minutes,
        smoothingFactor: FixidityLib.newFixedFraction(5, 1000).unwrap() // 0.005
      });
      rateFeedsConfig[i] = cfg;
    }

    // rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
    //   enabled: true,
    //   threshold: FixidityLib.newFixedFraction(4, 100), // 4%
    //   cooldown: 15 minutes,
    //   smoothingFactor: FixidityLib.newFixedFraction(5, 1000).unwrap() // 0.005
    // });

    return rateFeedsConfig;
  }

  function cUSDcEUR_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.celoRegistry("StableTokenEUR"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(5, 1000), // 0.5%, in line with current DT of chainlink feed
      referenceRateResetFrequency: 6 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID("relayed:EURUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      })
    });
  }

  function cUSDcREAL_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.celoRegistry("StableTokenBRL"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(3, 1000), // 0.3%, in line with current DT of chainlink feed
      referenceRateResetFrequency: 6 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID("relayed:BRLUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      // 1 USD ≈ 5 BRL
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 2_500_000,
        enabledGlobal: true,
        limitGlobal: 12_500_000
      })
    });
  }

  function cUSDeXOF_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.deployed("StableTokenXOFProxy"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(2, 100), // 2%, in line with current DT of chainlink feed
      referenceRateResetFrequency: 6 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID("relayed:XOFUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 50_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 250_000,
        enabledGlobal: true,
        limitGlobal: 1_000_000
      }),
      // 1 USD ≈ 555 XOF
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 27_750_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 138_750_000,
        enabledGlobal: true,
        limitGlobal: 555_000_000
      })
    });
  }
}
