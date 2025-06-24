// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;
import { Arrays } from "script/utils/Arrays.sol";

import { console2 } from "forge-std/console2.sol";
import { GovernanceScript } from "script/utils/Script.sol";
import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";
// import { TradingLimits } from "mento-core-2.5.0/libraries/TradingLimits.sol";
import { Config } from "script/utils/Config.sol";

// import { Config } from "script/utils/Config.sol";

contract PoolRestructuringConfig is GovernanceScript {
  // using TradingLimits for TradingLimits.Config;

  struct PoolToDelete {
    address asset0;
    address asset1;
    address rateFeedId;
  }

  struct SpreadOverride {
    address asset0;
    address asset1;
    address rateFeedId;
    FixidityLib.Fraction currentSpread;
    FixidityLib.Fraction targetSpread;
  }

  struct ValueDeltaBreakerOverride {
    address rateFeedId;
    uint256 currentThreshold;
    uint256 targetThreshold;
  }

  struct TradingLimitsOverride {
    address asset0;
    address asset1;
    // TradingLimits.Config asset0Config;
    // TradingLimits.Config asset1Config;
    address referenceRateFeedID;
    Config.TradingLimit asset0Config;
    Config.TradingLimit asset1Config;
  }

  mapping(address => string) private rateFeedIdToName;

  address private CELOProxy;
  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address private eXOFProxy;
  address private cKESProxy;
  address private cCADProxy;
  address private cAUDProxy;
  address private cCHFProxy;
  address private cGBPProxy;
  address private cZARProxy;
  address private cJPYProxy;
  address private cNGNProxy;
  address private PUSOProxy;
  address private cCOPProxy;
  address private cGHSProxy;

  address private nativeUSDCProxy;
  address private nativeUSDTProxy;
  address private axlUSDCProxy;
  address private axlEUROCProxy;

  function load() public {
    contracts.load("cKES-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("FX00-00-Deploy-Proxys", "latest");
    contracts.loadSilent("FX02-00-Deploy-Proxys", "latest");
    contracts.loadSilent("PUSO-00-Create-Proxies", "latest");
    contracts.loadSilent("cCOP-00-Create-Proxies", "latest");
    contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");

    CELOProxy = contracts.celoRegistry("GoldToken");
    cUSDProxy = contracts.celoRegistry("StableToken");
    cEURProxy = contracts.celoRegistry("StableTokenEUR");
    cBRLProxy = contracts.celoRegistry("StableTokenBRL");
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
    cKESProxy = contracts.deployed("StableTokenKESProxy");
    cCADProxy = contracts.deployed("StableTokenCADProxy");
    cAUDProxy = contracts.deployed("StableTokenAUDProxy");
    cCHFProxy = contracts.deployed("StableTokenCHFProxy");
    cGBPProxy = contracts.deployed("StableTokenGBPProxy");
    cZARProxy = contracts.deployed("StableTokenZARProxy");
    cJPYProxy = contracts.deployed("StableTokenJPYProxy");
    cNGNProxy = contracts.deployed("StableTokenNGNProxy");
    PUSOProxy = contracts.deployed("StableTokenPHPProxy");
    cCOPProxy = contracts.deployed("StableTokenCOPProxy");
    cGHSProxy = contracts.deployed("StableTokenGHSProxy");

    nativeUSDCProxy = contracts.dependency("NativeUSDC");
    nativeUSDTProxy = contracts.dependency("NativeUSDT");
    axlUSDCProxy = contracts.dependency("BridgedUSDC");
    axlEUROCProxy = contracts.dependency("BridgedEUROC");

    setFeedsNames();
  }

  function setFeedsNames() public {
    rateFeedIdToName[cUSDProxy] = "CELO/USD";
    rateFeedIdToName[cEURProxy] = "CELO/EUR";
    rateFeedIdToName[cBRLProxy] = "CELO/BRL";
    rateFeedIdToName[eXOFProxy] = "CELO/XOF";
    rateFeedIdToName[cKESProxy] = "CELO/KES";
    rateFeedIdToName[toRateFeedId("USDCUSD")] = "USDC/USD";
    rateFeedIdToName[toRateFeedId("USDCEUR")] = "USDC/EUR";
    rateFeedIdToName[toRateFeedId("USDCBRL")] = "USDC/BRL";
    rateFeedIdToName[toRateFeedId("EUROCEUR")] = "EUROC/EUR";
    rateFeedIdToName[toRateFeedId("EUROCXOF")] = "EUROC/XOF";
    rateFeedIdToName[toRateFeedId("EURXOF")] = "EUR/XOF";
    rateFeedIdToName[toRateFeedId("KESUSD")] = "KES/USD";
    rateFeedIdToName[toRateFeedId("USDTUSD")] = "USDT/USD";
    rateFeedIdToName[toRateFeedId("relayed:EURUSD")] = "EUR/USD";
    rateFeedIdToName[toRateFeedId("relayed:BRLUSD")] = "BRL/USD";
    rateFeedIdToName[toRateFeedId("relayed:XOFUSD")] = "XOF/USD";
    rateFeedIdToName[toRateFeedId("relayed:PHPUSD")] = "PHP/USD";
    rateFeedIdToName[toRateFeedId("relayed:CADUSD")] = "CAD/USD";
    rateFeedIdToName[toRateFeedId("relayed:AUDUSD")] = "AUD/USD";
    rateFeedIdToName[toRateFeedId("relayed:JPYUSD")] = "JPY/USD";
    rateFeedIdToName[toRateFeedId("relayed:NGNUSD")] = "NGN/USD";
    rateFeedIdToName[toRateFeedId("relayed:COPUSD")] = "COP/USD";
    rateFeedIdToName[toRateFeedId("relayed:GHSUSD")] = "GHS/USD";
    rateFeedIdToName[toRateFeedId("relayed:CHFUSD")] = "CHF/USD";
    rateFeedIdToName[toRateFeedId("relayed:ZARUSD")] = "ZAR/USD";
    rateFeedIdToName[toRateFeedId("relayed:GBPUSD")] = "GBP/USD";
  }

  function getFeedName(address rateFeedId) public view returns (string memory) {
    return rateFeedIdToName[rateFeedId];
  }

  function poolsToDelete() public view returns (PoolToDelete[] memory) {
    PoolToDelete[] memory pools = new PoolToDelete[](13);

    // non-USD pools that won't be re-created and will be gone for good
    pools[0] = PoolToDelete({ asset0: cEURProxy, asset1: CELOProxy, rateFeedId: cEURProxy });
    pools[1] = PoolToDelete({ asset0: cBRLProxy, asset1: CELOProxy, rateFeedId: cBRLProxy });
    pools[2] = PoolToDelete({ asset0: cBRLProxy, asset1: nativeUSDCProxy, rateFeedId: toRateFeedId("USDCBRL") });
    pools[3] = PoolToDelete({ asset0: cEURProxy, asset1: axlUSDCProxy, rateFeedId: toRateFeedId("USDCEUR") });
    pools[4] = PoolToDelete({ asset0: cBRLProxy, asset1: axlUSDCProxy, rateFeedId: toRateFeedId("USDCBRL") });
    pools[5] = PoolToDelete({ asset0: eXOFProxy, asset1: CELOProxy, rateFeedId: eXOFProxy });
    pools[6] = PoolToDelete({ asset0: eXOFProxy, asset1: axlEUROCProxy, rateFeedId: toRateFeedId("EUROCXOF") });
    pools[7] = PoolToDelete({ asset0: cEURProxy, asset1: nativeUSDCProxy, rateFeedId: toRateFeedId("USDCEUR") });

    // pools that will be re-created with a new spread, but need to be deleted first
    pools[8] = PoolToDelete({ asset0: cUSDProxy, asset1: nativeUSDCProxy, rateFeedId: toRateFeedId("USDCUSD") });
    pools[9] = PoolToDelete({ asset0: cUSDProxy, asset1: nativeUSDTProxy, rateFeedId: toRateFeedId("USDTUSD") });
    pools[10] = PoolToDelete({ asset0: cUSDProxy, asset1: axlUSDCProxy, rateFeedId: toRateFeedId("USDCUSD") });
    pools[11] = PoolToDelete({ asset0: cUSDProxy, asset1: cCADProxy, rateFeedId: toRateFeedId("relayed:CADUSD") });
    pools[12] = PoolToDelete({ asset0: cUSDProxy, asset1: cAUDProxy, rateFeedId: toRateFeedId("relayed:AUDUSD") });

    return pools;
  }

  function spreadOverrides() public view returns (SpreadOverride[] memory) {
    SpreadOverride[] memory overrides = new SpreadOverride[](5);
    // cUSD/nativeUSDC
    overrides[0] = SpreadOverride({
      asset0: cUSDProxy,
      asset1: nativeUSDCProxy,
      rateFeedId: toRateFeedId("USDCUSD"),
      currentSpread: FixidityLib.newFixedFraction(5, 10000), // 0.05%
      targetSpread: FixidityLib.newFixed(0) // 0%
    });
    // cUSD/USDT
    overrides[1] = SpreadOverride({
      asset0: cUSDProxy,
      asset1: nativeUSDTProxy,
      rateFeedId: toRateFeedId("USDTUSD"),
      currentSpread: FixidityLib.newFixedFraction(5, 10000), // 0.05%
      targetSpread: FixidityLib.newFixed(0) // 0%
    });
    // cUSD/axlUSDC
    overrides[2] = SpreadOverride({
      asset0: cUSDProxy,
      asset1: axlUSDCProxy,
      rateFeedId: toRateFeedId("USDCUSD"),
      currentSpread: FixidityLib.newFixedFraction(25, 10000), // 0.25%
      targetSpread: FixidityLib.newFixed(0) // 0%
    });
    // cUSD/cCAD
    overrides[3] = SpreadOverride({
      asset0: cUSDProxy,
      asset1: cCADProxy,
      rateFeedId: toRateFeedId("relayed:CADUSD"),
      currentSpread: FixidityLib.newFixedFraction(3, 1000), // 0.3%
      targetSpread: FixidityLib.newFixedFraction(15, 10000) // 0.15%
    });
    // cUSD/cAUD
    overrides[4] = SpreadOverride({
      asset0: cUSDProxy,
      asset1: cAUDProxy,
      rateFeedId: toRateFeedId("relayed:AUDUSD"),
      currentSpread: FixidityLib.newFixedFraction(3, 1000), // 0.3%
      targetSpread: FixidityLib.newFixedFraction(15, 10000) // 0.15%
    });

    return overrides;
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

  function tradingLimitsOverrides() public view returns (TradingLimitsOverride[] memory) {
    TradingLimitsOverride[] memory overrides = new TradingLimitsOverride[](13);

    // cEUR/axlEUROC
    overrides[0] = TradingLimitsOverride({
      asset0: cEURProxy,
      asset1: axlEUROCProxy,
      referenceRateFeedID: toRateFeedId("EUROCEUR"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1Config: Config.emptyTradingLimitConfig()
    });

    // cUSD/nativeUSDT
    overrides[1] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: nativeUSDTProxy,
      referenceRateFeedID: toRateFeedId("USDTUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 2_500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 5_000_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1Config: Config.emptyTradingLimitConfig()
    });

    // cUSD/PUSO
    overrides[2] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: PUSOProxy,
      referenceRateFeedID: toRateFeedId("relayed:PHPUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 5_700_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 28_500_000,
        enabledGlobal: true,
        limitGlobal: 142_500_000
      })
    });

    // cUSD/JPY
    overrides[3] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: cJPYProxy,
      referenceRateFeedID: toRateFeedId("relayed:JPYUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 14_200_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 71_000_000,
        enabledGlobal: true,
        limitGlobal: 355_000_000
      })
    });

    // cUSD/cCOP
    overrides[4] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: cCOPProxy,
      referenceRateFeedID: toRateFeedId("relayed:COPUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 50_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 250_000,
        enabledGlobal: true,
        limitGlobal: 1_250_000
      }),
      asset1Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 210_550_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_052_750_000,
        enabledGlobal: true,
        limitGlobal: 5_263_750_000
      })
    });

    // cUSD/cGHS
    overrides[5] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: cGHSProxy,
      referenceRateFeedID: toRateFeedId("relayed:GHSUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 50_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 250_000,
        enabledGlobal: true,
        limitGlobal: 1_250_000
      }),
      asset1Config: Config.TradingLimit({
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

    // cUSD/cGBP
    overrides[6] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: cGBPProxy,
      referenceRateFeedID: toRateFeedId("relayed:GBPUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 77_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 385_000,
        enabledGlobal: true,
        limitGlobal: 1_925_000
      })
    });

    // cUSD/cZAR
    overrides[7] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: cZARProxy,
      referenceRateFeedID: toRateFeedId("relayed:ZARUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 1_800_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 9_000_000,
        enabledGlobal: true,
        limitGlobal: 45_000_000
      })
    });

    // cUSD/cCAD
    overrides[8] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: cCADProxy,
      referenceRateFeedID: toRateFeedId("relayed:CADUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 140_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 700_000,
        enabledGlobal: true,
        limitGlobal: 3_500_000
      })
    });

    // cUSD/cAUD
    overrides[9] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: cAUDProxy,
      referenceRateFeedID: toRateFeedId("relayed:AUDUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 160_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 800_000,
        enabledGlobal: true,
        limitGlobal: 4_000_000
      })
    });

    // cUSD/cCHF
    overrides[10] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: cCHFProxy,
      referenceRateFeedID: toRateFeedId("relayed:CHFUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 83_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 415_000,
        enabledGlobal: true,
        limitGlobal: 2_075_000
      })
    });

    // cUSD/cNGN
    overrides[11] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: cNGNProxy,
      referenceRateFeedID: toRateFeedId("relayed:NGNUSD"),
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 161_200_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 806_000_000,
        enabledGlobal: true,
        limitGlobal: 4_030_000_000
      })
    });

    // cUSD/CELO
    overrides[12] = TradingLimitsOverride({
      asset0: cUSDProxy,
      asset1: CELOProxy,
      referenceRateFeedID: cUSDProxy,
      asset0Config: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1Config: Config.emptyTradingLimitConfig()
    });

    return overrides;
  }

  function shouldBeDeleted(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool) {
    PoolToDelete[] memory pools = poolsToDelete();
    for (uint256 i = 0; i < pools.length; i++) {
      if (pools[i].asset0 == poolCfg.asset0 && pools[i].asset1 == poolCfg.asset1) {
        require(pools[i].rateFeedId == poolCfg.config.referenceRateFeedID, "Rate feed ID mismatch in pool to delete");
        return true;
      }
    }

    return false;
  }

  function shouldRecreateWithNewSpread(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool) {
    SpreadOverride[] memory overrides = spreadOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        return true;
      }
    }

    return false;
  }

  function getPoolCfgWithNewSpread(
    IBiPoolManager.PoolExchange memory currentExchange
  ) public view returns (IBiPoolManager.PoolExchange memory) {
    IBiPoolManager.PoolExchange memory newExchange = currentExchange;
    (FixidityLib.Fraction memory currentSpread, FixidityLib.Fraction memory targetSpread) = getCurrentAndTargetSpread(
      currentExchange
    );
    require(
      FixidityLib.equals(newExchange.config.spread, currentSpread),
      "❌ Current spread mismatch on spread override"
    );

    newExchange.config.spread = targetSpread;
    // Automatically adjusted by the biPoolManager upon creation
    newExchange.bucket0 = 0;
    newExchange.bucket1 = 0;
    newExchange.lastBucketUpdate = 0;

    return newExchange;
  }

  function hasNewSpread(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool) {
    SpreadOverride[] memory overrides = spreadOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        require(
          overrides[i].rateFeedId == poolCfg.config.referenceRateFeedID,
          "Rate feed ID mismatch on spread override"
        );
        return true;
      }
    }

    return false;
  }

  function getCurrentAndTargetSpread(
    IBiPoolManager.PoolExchange memory poolCfg
  ) public view returns (FixidityLib.Fraction memory, FixidityLib.Fraction memory) {
    SpreadOverride[] memory overrides = spreadOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        return (overrides[i].currentSpread, overrides[i].targetSpread);
      }
    }

    require(false, "getCurrentAndTargetSpread() called on a pool with no spread override");
  }
}
