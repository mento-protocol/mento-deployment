// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";
import { Arrays } from "script/utils/Arrays.sol";

/**
 * @dev This library contains the configuration required for the FX01 governance proposal.
 *      The following configuration is used:
 *     - 4 pools:
 *              - cGBP<->cUSD
 *              - cZAR<->cUSD
 *              - cCAD<->cUSD
 *              - cAUD<->cUSD
 *
 *     - 4 rate feeds:
 *              - GBPUSD
 *              - ZARUSD
 *              - CADUSD
 *              - AUDUSD
 *
 *     - Configuration params needed to initialize all four tokens
 */
library FX01Config {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct FX01 {
    Config.Pool cGBPcUSD;
    Config.Pool cZARcUSD;
    Config.Pool cCADcUSD;
    Config.Pool cAUDcUSD;
    Config.Pool[] pools;
    Config.RateFeed GBPUSD;
    Config.RateFeed ZARUSD;
    Config.RateFeed CADUSD;
    Config.RateFeed AUDUSD;
    Config.RateFeed[] rateFeeds;
    Config.StableTokenV2 cGBPConfig;
    Config.StableTokenV2 cZARConfig;
    Config.StableTokenV2 cCADConfig;
    Config.StableTokenV2 cAUDConfig;
    Config.StableTokenV2[] stableTokenConfigs;
    address payable[] stableTokenAddresses;
  }

  /**
   * @dev Returns the populated configuration object for the FX01 governance proposal.
   */
  function get(Contracts.Cache storage contracts) internal view returns (FX01 memory config) {
    config.pools = new Config.Pool[](4);
    config.pools[0] = cGBPcUSD_PoolConfig(contracts);
    config.pools[1] = cZARcUSD_PoolConfig(contracts);
    config.pools[2] = cCADcUSD_PoolConfig(contracts);
    config.pools[3] = cAUDcUSD_PoolConfig(contracts);

    config.rateFeeds = new Config.RateFeed[](4);
    config.rateFeeds[0] = GBPUSD_RateFeedConfig();
    config.rateFeeds[1] = ZARUSD_RateFeedConfig();
    config.rateFeeds[2] = CADUSD_RateFeedConfig();
    config.rateFeeds[3] = AUDUSD_RateFeedConfig();

    config.stableTokenConfigs = new Config.StableTokenV2[](4);
    config.stableTokenConfigs[0] = stableTokenGBPConfig();
    config.stableTokenConfigs[1] = stableTokenZARConfig();
    config.stableTokenConfigs[2] = stableTokenCADConfig();
    config.stableTokenConfigs[3] = stableTokenAUDConfig();

    config.stableTokenAddresses = new address payable[](4);
    config.stableTokenAddresses[0] = contracts.deployed("StableTokenGBPProxy");
    config.stableTokenAddresses[1] = contracts.deployed("StableTokenZARProxy");
    config.stableTokenAddresses[2] = contracts.deployed("StableTokenCADProxy");
    config.stableTokenAddresses[3] = contracts.deployed("StableTokenAUDProxy");
  }

  /* ==================== Rate Feed Configurations ==================== */

  /**
   * @dev Returns the default configuration for a MedianDeltaBreaker.
   */
  function getDefaultMedianDeltaBreakerConfig() internal pure returns (Config.MedianDeltaBreaker memory) {
    return
      Config.MedianDeltaBreaker({
        enabled: true,
        threshold: FixidityLib.newFixedFraction(4, 100), // 4%
        cooldown: 15 minutes,
        smoothingFactor: FixidityLib.newFixedFraction(5, 1000).unwrap() // 0.005
      });
  }

  /**
   * @dev Returns a RateFeed configuration for the specified rate feed ID.
   */
  function createRateFeedConfig(
    string memory rateFeedName
  ) internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID(string(abi.encodePacked("relayed:", rateFeedName)));
    rateFeedConfig.medianDeltaBreaker0 = getDefaultMedianDeltaBreakerConfig();
  }

  /**
   * @dev Returns the configuration for the GBPUSD rate feed.
   */
  function GBPUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory) {
    return createRateFeedConfig("GBPUSD");
  }

  /**
   * @dev Returns the configuration for the ZARUSD rate feed.
   */
  function ZARUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory) {
    return createRateFeedConfig("ZARUSD");
  }

  /**
   * @dev Returns the configuration for the CADUSD rate feed.
   */
  function CADUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory) {
    return createRateFeedConfig("CADUSD");
  }

  /**
   * @dev Returns the configuration for the AUDUSD rate feed.
   */
  function AUDUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory) {
    return createRateFeedConfig("AUDUSD");
  }

  /* ==================== Pool Configurations ==================== */

  /**
   * @dev Returns default trading limits for asset0 (cUSD)
   */
  function getDefaultAsset0Limits() internal pure returns (Config.TradingLimit memory) {
    return
      Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 200_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_000_000,
        enabledGlobal: true,
        limitGlobal: 5_000_000
      });
  }

  /**
   * @dev Returns trading limits for asset1 with rate calculated using FixidityLib
   */
  function getAsset1LimitsWithFixidity(
    FixidityLib.Fraction memory rate
  ) internal pure returns (Config.TradingLimit memory) {
    return
      Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: uint256(FixidityLib.newFixed(200_000).multiply(rate).fromFixed()),
        enabled1: true,
        timeStep1: 1 days,
        limit1: uint256(FixidityLib.newFixed(1_000_000).multiply(rate).fromFixed()),
        enabledGlobal: true,
        limitGlobal: uint256(FixidityLib.newFixed(5_000_000).multiply(rate).fromFixed())
      });
  }

  /**
   * @dev Creates a base pool configuration with rates handled by FixidityLib
   */
  function createBasePoolConfigWithFixidity(
    Contracts.Cache storage contracts,
    address payable asset1,
    string memory rateFeedName,
    FixidityLib.Fraction memory rate
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: asset1,
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(3, 1000),
      referenceRateResetFrequency: 6 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID(string(abi.encodePacked("relayed:", rateFeedName))),
      asset0limits: getDefaultAsset0Limits(),
      asset1limits: getAsset1LimitsWithFixidity(rate)
    });
  }

  /**
   * @dev Returns the configuration for the cGBPcUSD pool.
   */
  function cGBPcUSD_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory) {
    return
      createBasePoolConfigWithFixidity(
        contracts,
        contracts.deployed("StableTokenGBPProxy"),
        "GBPUSD",
        FixidityLib.newFixedFraction(77, 1000) // 0.77
      );
  }

  /**
   * @dev Returns the configuration for the cZARcUSD pool.
   */
  function cZARcUSD_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory) {
    return
      createBasePoolConfigWithFixidity(
        contracts,
        contracts.deployed("StableTokenZARProxy"),
        "ZARUSD",
        FixidityLib.newFixedFraction(18, 100) // 18
      );
  }

  /**
   * @dev Returns the configuration for the cCADcUSD pool.
   */
  function cCADcUSD_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory) {
    return
      createBasePoolConfigWithFixidity(
        contracts,
        contracts.deployed("StableTokenCADProxy"),
        "CADUSD",
        FixidityLib.newFixedFraction(143, 10000) // 1.43
      );
  }

  /**
   * @dev Returns the configuration for the cAUDcUSD pool.
   */
  function cAUDcUSD_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory) {
    return
      createBasePoolConfigWithFixidity(
        contracts,
        contracts.deployed("StableTokenAUDProxy"),
        "AUDUSD",
        FixidityLib.newFixedFraction(159, 10000) // 1.59
      );
  }

  /* ==================== Stable Token Configurations ==================== */

  /**
   * @dev Returns the configuration for the cGBP stable token.
   */
  function stableTokenGBPConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo British Pound", symbol: "cGBP" });
  }

  /**
   * @dev Returns the configuration for the cZAR stable token.
   */
  function stableTokenZARConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo South African Rand", symbol: "cZAR" });
  }

  /**
   * @dev Returns the configuration for the cCAD stable token.
   */
  function stableTokenCADConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Canadian Dollar", symbol: "cCAD" });
  }

  /**
   * @dev Returns the configuration for the cAUD stable token.
   */
  function stableTokenAUDConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Australian Dollar", symbol: "cAUD" });
  }
}
