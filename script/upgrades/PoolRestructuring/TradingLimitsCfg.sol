// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";

import { Config } from "script/utils/Config.sol";
import { CfgHelper } from "script/upgrades/PoolRestructuring/CfgHelper.sol";

contract TradingLimitsCfg is GovernanceScript {
  CfgHelper private cfgHelper;

  struct Override {
    address asset0;
    address asset1;
    address referenceRateFeedID;
    Config.TradingLimit asset0Config;
    Config.TradingLimit asset1Config;
  }

  constructor(CfgHelper _cfgHelper) public {
    cfgHelper = _cfgHelper;
  }

  function tradingLimitsOverrides() public view returns (Override[] memory) {
    Override[] memory overrides = new Override[](13);

    // cEUR/axlEUROC
    overrides[0] = Override({
      asset0: cfgHelper.cEURProxy(),
      asset1: cfgHelper.axlEUROCProxy(),
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
    overrides[1] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.nativeUSDTProxy(),
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
    overrides[2] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.PUSOProxy(),
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
      // 1 USD ≈ 57 PHP
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

    // cUSD/cJPY
    overrides[3] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cJPYProxy(),
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
      // 1 USD ≈ 142 PHP
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
    overrides[4] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cCOPProxy(),
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
      // 1 USD ≈ 4,200 COP
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
    overrides[5] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cGHSProxy(),
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
      // 1 USD ≈ 10 GHS
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
    overrides[6] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cGBPProxy(),
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
      // 1 USD ≈ 0.77 GBP
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
    overrides[7] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cZARProxy(),
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
      // 1 USD ≈ 18 ZAR
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
    overrides[8] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cCADProxy(),
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
      // 1 USD ≈ 1.4 CAD
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
    overrides[9] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cAUDProxy(),
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
      // 1 USD ≈ 1.6 AUD
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
    overrides[10] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cCHFProxy(),
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
      // 1 USD ≈ 0.83 CHF
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
    overrides[11] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.cNGNProxy(),
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
      // 1 USD ≈ 1612 NGN
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
    overrides[12] = Override({
      asset0: cfgHelper.cUSDProxy(),
      asset1: cfgHelper.CELOProxy(),
      referenceRateFeedID: cfgHelper.cUSDProxy(),
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
}
