// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";

contract CfgHelper is GovernanceScript {
  address public CELOProxy;
  address public cUSDProxy;
  address public cEURProxy;
  address public cBRLProxy;
  address public eXOFProxy;
  address public cKESProxy;
  address public cCADProxy;
  address public cAUDProxy;
  address public cCHFProxy;
  address public cGBPProxy;
  address public cZARProxy;
  address public cJPYProxy;
  address public cNGNProxy;
  address public PUSOProxy;
  address public cCOPProxy;
  address public cGHSProxy;

  address public nativeUSDCProxy;
  address public nativeUSDTProxy;
  address public axlUSDCProxy;
  address public axlEUROCProxy;

  mapping(address => string) public rateFeedIdToName;

  function load() public {
    contracts.loadSilent("cKES-00-Create-Proxies", "latest");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");
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

  function setFeedsNames() internal {
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
}
