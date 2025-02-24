// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { GDChecksBase } from "./GDChecks.base.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Broker } from "mento-core-2.6.0/swap/Broker.sol";
import { IReserve } from "mento-core-2.6.0/interfaces/IReserve.sol";

interface IProxyLite {
  function _getImplementation() external view returns (address);

  function _getOwner() external view returns (address);

  function _transferOwnership(address) external;

  function _setImplementation(address newImplementation) external;

  function _setAndInitializeImplementation(address implementation, bytes calldata callbackData) external;
}

interface IOwnableLite {
  function owner() external view returns (address);
}

contract GDChecksVerify is GDChecksBase {
  constructor() {
    setUp();
  }

  function run() public {
    console.log("\nStarting GoodDollar x Mento upgrade checks:");

    //verifyBroker();
    verifyGoodDollarReserve();
  }

  function verifyBroker() public {
    console.log("\n== Verify Broker upgrade ==");

    address brokerImplementation = IProxyLite(brokerProxy)._getImplementation();
    require(brokerImplementation == newBrokerImplementation, "Broker implementation mismatch");
    console.log("Broker implementation upgraded successfully");

    address brokerImplementationOwner = IOwnableLite(brokerImplementation).owner();
    require(brokerImplementationOwner == timelock, "Broker implementation not owned by timelock");
    console.log("New Broker implementation owned by timelock");

    require(
      Broker(brokerProxy).isExchangeProvider(biPoolManagerProxy),
      "BiPoolManager not added to Broker as ExchangeProvider"
    );
    address biPoolManagerReserve = Broker(brokerProxy).exchangeReserve(biPoolManagerProxy);
    require(biPoolManagerReserve == mentoReserveProxy, "BiPoolManager Reserve mismatch");
    console.log("BiPoolManager Reserve is configured correctly");

    require(
      Broker(brokerProxy).isExchangeProvider(goodDollarExchangeProviderProxy),
      "GoodDollar ExchangeProvider not added to Broker"
    );
    address goodDollarReserve = Broker(brokerProxy).exchangeReserve(goodDollarExchangeProviderProxy);
    require(goodDollarReserve == goodDollarReserveProxy, "GoodDollar Reserve mismatch");
    console.log("IExchangeProvider -> IReserve mapping is configured correctly");

    console.log("== Broker upgrade successful ==");
  }

  function verifyGoodDollarReserve() public {
    console.log("\n== Verify GoodDollar Reserve ==");

    // address goodDollarReserveImplementation = IProxyLite(goodDollarReserveProxy)._getImplementation();

    // require(goodDollarReserveImplementation == reserveImplementation, "GoodDollar Reserve implementation mismatch");
    // console.log("GoodDollar Reserve implementation is correct");

    address goodDollarReserveOwner = IOwnableLite(goodDollarReserveProxy).owner();
    console.log("GoodDollar Reserve owner", goodDollarReserveOwner);
    require(goodDollarReserveOwner == timelock, "GoodDollar Reserve not owned by timelock");
    console.log("GoodDollar Reserve is owned by timelock");

    // require(
    //   IReserve(goodDollarReserveProxy).isExchangeSpender(brokerProxy),
    //   "Broker not added as Spender to GoodDollar Reserve"
    // );
    // console.log("Broker is added as Exchange Spender to GoodDollar Reserve");

    // require(
    //   IReserve(goodDollarReserveProxy).isStableAsset(goodDollarToken),
    //   "GoodDollar not added as StableAsset to GoodDollar Reserve"
    // );
    // console.log("GoodDollar is added as StableAsset to GoodDollar Reserve");

    // console.log("GoodDollar Reserve configured successfully");
  }
}
