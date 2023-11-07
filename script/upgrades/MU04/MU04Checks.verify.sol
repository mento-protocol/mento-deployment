// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";
import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";

import { IStableTokenV2 } from "mento-core-2.2.0/interfaces/IStableTokenV2.sol";
import { IExchange } from "mento-core-2.2.0/legacy/interfaces/IExchange.sol";
import { IProxy } from "mento-core-2.2.0/common/interfaces/IProxy.sol";
import { IFreezer } from "../../interfaces/IFreezer.sol";
import { IRegistry } from "mento-core-2.2.0/common/interfaces/IRegistry.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { ICeloGovernance } from "script/interfaces/ICeloGovernance.sol";

import { Reserve } from "mento-core-2.2.0/swap/Reserve.sol";
import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";

import { MU04ChecksBase } from "./MU04Checks.base.sol";
import { MU04Config, Config } from "./Config.sol";

/**
 * @title IBrokerWithCasts
 * @notice Interface for Broker with tuple -> struct casting
 * @dev This is used to access the internal trading limits
 * config as a struct as opposed to a tuple.
 */
interface IBrokerWithCasts {
  function tradingLimitsConfig(bytes32 id) external view returns (TradingLimits.Config memory);
}

interface IOwnableLite {
  function owner() external view returns (address);
}

contract MU04ChecksVerify is MU04ChecksBase {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;
  ICeloGovernance public celoGovernance;

  constructor() public {
    setUp();
    celoGovernance = ICeloGovernance(governance);
  }

  function run() public {
    console.log("\nStarting MU04 checks:");
    MU04Config.MU04 memory config = MU04Config.get(contracts);
    verifyStableTokens();

    verifyExchangesAreFrozen();
    verifyExchangeSwapsRevert();

    verifyRegistryChanges();

    verifyReserveImplementation();
    verifyReserveExchangeSpender();
    verifyReserveCollateralAssets();
    verifyReserveTokens();
    verifyReserveSpenders();
    verifyReserveReferenceInBroker();
    verifyReserveReferenceInBiPoolManager();

    verifyTradingLimits(config);
  }

  function verifyStableTokens() internal {
    address[] memory stableTokenProxies = Arrays.addresses(cUSDProxy, cEURProxy, cBRLProxy, eXOFProxy);
    for (uint i = 0; i < stableTokenProxies.length; i++) {
      console.log("\n== Verifying StableToken  %s ==", stableTokenProxies[i]);

      require(
        IProxy(stableTokenProxies[i])._getImplementation() == stableTokenV2,
        "❗️❌ StableToken ProxyImplementation is not set to V2"
      );
      console.log("🟢 StableTokenProxy implementation of %s verified.", stableTokenProxies[i]);

      require(
        IStableTokenV2(stableTokenProxies[i]).broker() == brokerProxy,
        "❗️❌ StableTokenV2 broker is not set correctly"
      );
      console.log("🟢 StableTokenV2 broker in %s is set correctly.", stableTokenProxies[i]);

      require(
        IStableTokenV2(stableTokenProxies[i]).validators() == validators,
        "❗️❌ StableTokenV2 validators are not set correctly"
      );
      console.log("🟢 StableTokenV2 validators in %s are set correctly.", stableTokenProxies[i]);

      require(
        IStableTokenV2(stableTokenProxies[i]).exchange() == address(0),
        "❗️❌ StableTokenV2 exchange is not set correctly"
      );
      console.log("🟢 StableTokenV2 exchange in %s is set correctly.", stableTokenProxies[i]);
    }
    require(
      IOwnableLite(stableTokenV2).owner() == governance,
      "❗️❌ StableTokenV2 implementation ownership not transferred to governance"
    );
    console.log("🟢 StableTokenV2 implementation ownership transferred to governance");
  }

  function verifyExchangesAreFrozen() internal {
    console.log("\n== Verifying Exchanges are frozen ==");
    address[] memory exchanges = Arrays.addresses(exchangeProxy, exchangeEURProxy, exchangeBRLProxy);

    for (uint i = 0; i < exchanges.length; i++) {
      require(IFreezer(freezerProxy).isFrozen(exchanges[i]), "❗️❌ Exchange is not frozen");
      console.log("🟢 Exchange %s is frozen", exchanges[i]);
    }
  }

  function verifyExchangeSwapsRevert() internal {
    console.log("\n== Verifying Exchange buy() and sell() are disabled ==");
    address trader = vm.addr(361);
    vm.deal(trader, 300e18);
    address[] memory exchanges = Arrays.addresses(exchangeProxy, exchangeEURProxy, exchangeBRLProxy);

    for (uint i = 0; i < exchanges.length; i++) {
      vm.startPrank(trader);
      IERC20(celoToken).approve(exchanges[i], 100e18);
      vm.expectRevert("can't call when contract is frozen");
      IExchange(exchanges[i]).sell(50e18, 0, true);
      vm.expectRevert("can't call when contract is frozen");
      IExchange(exchanges[i]).buy(1e18, 50e18, false);

      console.log("🟢 Exchange %s swap attempts revert", exchanges[i]);
    }
  }

  function verifyRegistryChanges() internal {
    console.log("\n== Verifying Registry Changes ==");
    bytes32[] memory exchangesV1 = Arrays.bytes32s("Exchange", "ExchangeEUR", "ExchangeBRL", "GrandaMento");
    for (uint i = 0; i < exchangesV1.length; i++) {
      require(
        IRegistry(REGISTRY_ADDRESS).getAddressForString(bytes32ToStr(exchangesV1[i])) == address(0),
        "❗️❌ Exchange is still registered"
      );
    }
    console.log("🟢 Exchanges removed from registry");
  }

  function verifyReserveImplementation() internal {
    console.log("\n== Verifying Main Reserve Implementation ==");
    require(
      IProxy(reserveProxy)._getImplementation() == newReserveImplementation,
      "❗️❌ Main Reserve Implementation is not set correctly"
    );
    console.log("🟢 Main Reserve Implementation set correctly");
  }

  function verifyReserveExchangeSpender() internal {
    console.log("\n== Verifying Main Reserve Exchange Spender ==");
    require(Reserve(reserveProxy).isExchangeSpender(brokerProxy), "❗️❌ Broker wasn't added to exchange spender list");
    console.log("🟢 Broker successfully added to exchange spender list");

    require(
      Reserve(reserveProxy).getExchangeSpenders().length == 1,
      "❗️❌ Reserve Exchange Spender not updated correctly"
    );
    console.log("🟢 Exchange spender list correctly updated");
  }

  function verifyReserveCollateralAssets() internal {
    console.log("\n== Verifying Main Reserve Collateral Assets ==");

    address[] memory collateralAssets = Arrays.addresses(celoToken, bridgedUSDC, bridgedEUROC);
    // mint some EUROC/USDC to the main reserve in order to verify spending ratios
    deal(bridgedUSDC, reserveProxy, 100e6);
    deal(bridgedEUROC, reserveProxy, 100e6);
    // TODO: update this when spending ratios are set
    uint256[] memory spendingRatios = Arrays.uints(1e24 * 0.5, 1e24 * 0.5, 1e24 * 0.5);
    for (uint i = 0; i < collateralAssets.length; i++) {
      require(
        Reserve(reserveProxy).isCollateralAsset(collateralAssets[i]),
        "❗️❌ Reserve collateral asset not set correctly"
      );
      verifyCollateralSpendingRatio(collateralAssets[i], spendingRatios[i]);
      console.log("🟢 Asset: %s successfully added to collateral asset list", collateralAssets[i]);
    }
  }

  function verifyReserveTokens() internal {
    console.log("\n== Verifying Main Reserve Tokens ==");
    require(Reserve(reserveProxy).isToken(eXOFProxy), "❗️❌ eXOF not added to Reserve StableToken list ");
    console.log("🟢 eXOF successfully added to Reserve StableToken list");
  }

  function verifyReserveSpenders() internal {
    console.log("\n== Verifying Main Reserve Spenders ==");
    require(
      Reserve(reserveProxy).isSpender(contracts.dependency("PartialReserveMultisig")),
      "❗️❌ Partial reserve multisig not added to Reserve spender list"
    );
    console.log("🟢 Partial reserve multisig successfully added to Reserve spender list");

    require(
      !Reserve(reserveProxy).isSpender(oldMainReserveMultisig),
      "❗️❌ Old main reserve multisig is still in Reserve spender list"
    );
    console.log("🟢 Old main reserve multisig successfully removed from Reserve spender list");
  }

  function verifyReserveReferenceInBroker() internal {
    console.log("\n== Verifying Reserve reference in Broker ==");
    require(
      address(Broker(brokerProxy).reserve()) == reserveProxy,
      "❗️❌ Reserve reference in Broker not set to main reserve"
    );
    console.log("🟢 Reserve reference in Broker set correctly");
  }

  function verifyReserveReferenceInBiPoolManager() internal {
    console.log("\n== Verifying Reserve reference in BiPoolManager ==");
    require(
      address(BiPoolManager(biPoolManagerProxy).reserve()) == reserveProxy,
      "❗️❌ Reserve reference in BiPoolManager not set to main reserve"
    );
    console.log("🟢 Reserve reference in BiPoolManager set correctly");
  }

  function verifyTradingLimits(MU04Config.MU04 memory config) internal view {
    console.log("\n== Verifying TradingLimits changes in Broker ==");
    IBrokerWithCasts _broker = IBrokerWithCasts(brokerProxy);

    for (uint256 i = 0; i < config.pools.length; i++) {
      bytes32 exchangeId = getExchangeId(config.pools[i].asset0, config.pools[i].asset1, config.pools[i].isConstantSum);
      Config.Pool memory poolConfig = config.pools[i];

      bytes32 asset0LimitId = exchangeId ^ bytes32(uint256(uint160(config.pools[i].asset0)));
      TradingLimits.Config memory asset0ActualLimit = _broker.tradingLimitsConfig(asset0LimitId);

      bytes32 asset1LimitId = exchangeId ^ bytes32(uint256(uint160(config.pools[i].asset1)));
      TradingLimits.Config memory asset1ActualLimit = _broker.tradingLimitsConfig(asset1LimitId);

      checkTradingLimt(poolConfig.asset0limits, asset0ActualLimit);
      checkTradingLimt(poolConfig.asset1limits, asset1ActualLimit);
    }

    console.log("🟢 Trading limits correctly updated for all exchanges 🔒");
  }

  function checkTradingLimt(
    Config.TradingLimit memory expectedTradingLimit,
    TradingLimits.Config memory actualTradingLimit
  ) internal view {
    if (expectedTradingLimit.limit0 != actualTradingLimit.limit0) {
      console.log("limit0 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.limit1 != actualTradingLimit.limit1) {
      console.log("limit1 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.limitGlobal != actualTradingLimit.limitGlobal) {
      console.log("limitGlobal was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.timeStep0 != actualTradingLimit.timestep0) {
      console.log("timestep0 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.timeStep1 != actualTradingLimit.timestep1) {
      console.log("timestep1 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }

    uint8 tradingLimitFlags = Config.tradingLimitConfigToFlag(expectedTradingLimit);
    if (tradingLimitFlags != actualTradingLimit.flags) {
      console.log("flags were not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
  }

  function bytes32ToStr(bytes32 _bytes32) public view returns (string memory) {
    uint256 length = 0;
    while (bytes1(_bytes32[length]) != 0) {
      length++;
    }

    bytes memory bytesArray = new bytes(length);
    for (uint256 i; i < length; i++) {
      bytesArray[i] = _bytes32[i];
    }
    return string(bytesArray);
  }

  function verifyCollateralSpendingRatio(address collateralAsset, uint256 expectedRatio) internal {
    console.log("\n== Verifying Collateral Spending Ratio for %s ==", collateralAsset);
    // @notice verifiying spending ratios by trying moving the allowed and more than the allowed amount
    // the variable holding the ratios is private

    address[] memory otherReserveAddresses = Reserve(reserveProxy).getOtherReserveAddresses();
    address payable otherReserve = address(uint160(otherReserveAddresses[0]));
    uint256 reserveBalance = Reserve(reserveProxy).getReserveAddressesCollateralAssetBalance(collateralAsset);

    uint256 spendingLimit = FixidityLib.wrap(expectedRatio).multiply(FixidityLib.newFixed(reserveBalance)).fromFixed();
    uint256 exceedingAmount = spendingLimit + 1;

    vm.prank(partialReserveMultisig);
    vm.expectRevert("Exceeding spending limit");
    Reserve(reserveProxy).transferCollateralAsset(collateralAsset, otherReserve, exceedingAmount);
    console.log("🟢 Couldn't transfer more than the allowed amount");

    vm.prank(partialReserveMultisig);
    Reserve(reserveProxy).transferCollateralAsset(collateralAsset, otherReserve, spendingLimit);
    console.log("🟢 Successfully transferred the max allowed amount");

    console.log("🟢 Spending ratio for Asset: %s successfully set to ", collateralAsset, expectedRatio);
  }
}
