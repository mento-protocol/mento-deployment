// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { GovernanceScript } from "script/utils/Script.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { IReserve } from "mento-core-2.6.0/interfaces/IReserve.sol";
import { IERC20 } from "mento-core-2.6.0/interfaces/IERC20.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IOwnableLite {
  function owner() external view returns (address);

  function transferOwnership(address recipient) external;
}

interface IProxyLite {
  function _getImplementation() external view returns (address);

  function _getOwner() external view returns (address);
}

contract MU08Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  // Celo Governance:
  address private celoGovernance;

  //Tokens:
  address private CELOProxy;
  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address private eXOFProxy;
  address private cKESProxy;
  address private PUSOProxy;
  address private cCOPProxy;
  address private cGHSProxy;
  address private cGBPProxy;
  address private cAUDProxy;
  address private cCADProxy;
  address private cZARProxy;

  // MentoV2 contracts:
  address private brokerProxy;
  address private biPoolManagerProxy;
  address private reserveProxy;
  address private breakerBox;
  address private medianDeltaBreaker;
  address private valueDeltaBreaker;

  // MentoV1 contracts:
  address private exchangeProxy;
  address private exchangeEURProxy;
  address private exchangeBRLProxy;
  address private grandaMentoProxy;

  // MentoGovernance contracts:
  address private governanceFactory;
  address private timelockProxy;

  // Mento Reserve Multisig address:
  address private reserveMultisig;

  // Celo Custody Reserve address:
  address private celoCustodyReserve;

  function prepare() public {
    // Load addresses from deployments
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("cKES-00-Create-Proxies", "latest");
    contracts.loadSilent("PUSO-00-Create-Proxies", "latest");
    contracts.loadSilent("cCOP-00-Create-Proxies", "latest");
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");
    contracts.loadSilent("MU08-00-Create-Proxies", "latest");
    contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");
    contracts.loadSilent("FX00-00-Deploy-Proxys", "latest");

    // Celo Governance:
    celoGovernance = contracts.celoRegistry("Governance");

    // Tokens:
    CELOProxy = address(uint160(contracts.celoRegistry("GoldToken")));
    cUSDProxy = address(uint160(contracts.celoRegistry("StableToken")));
    cEURProxy = address(uint160(contracts.celoRegistry("StableTokenEUR")));
    cBRLProxy = address(uint160(contracts.celoRegistry("StableTokenBRL")));
    eXOFProxy = address(uint160(contracts.deployed("StableTokenXOFProxy")));
    cKESProxy = address(uint160(contracts.deployed("StableTokenKESProxy")));
    PUSOProxy = address(uint160(contracts.deployed("StableTokenPHPProxy")));
    cCOPProxy = address(uint160(contracts.deployed("StableTokenCOPProxy")));
    cGHSProxy = address(uint160(contracts.deployed("StableTokenGHSProxy")));
    cGBPProxy = address(uint160(contracts.deployed("StableTokenGBPProxy")));
    cAUDProxy = address(uint160(contracts.deployed("StableTokenAUDProxy")));
    cCADProxy = address(uint160(contracts.deployed("StableTokenCADProxy")));
    cZARProxy = address(uint160(contracts.deployed("StableTokenZARProxy")));

    // MentoV2 contracts:
    brokerProxy = address(uint160(contracts.deployed("BrokerProxy")));
    biPoolManagerProxy = address(uint160(contracts.deployed("BiPoolManagerProxy")));
    reserveProxy = address(uint160(contracts.celoRegistry("Reserve")));
    breakerBox = address(uint160(contracts.deployed("BreakerBox")));
    medianDeltaBreaker = address(uint160(contracts.deployed("MedianDeltaBreaker")));
    valueDeltaBreaker = address(uint160(contracts.deployed("ValueDeltaBreaker")));

    // MentoV1 contracts:
    exchangeProxy = contracts.dependency("Exchange");
    exchangeEURProxy = contracts.dependency("ExchangeEUR");
    exchangeBRLProxy = contracts.dependency("ExchangeBRL");
    grandaMentoProxy = contracts.dependency("GrandaMento");

    // MentoGovernance contracts:
    governanceFactory = contracts.deployed("GovernanceFactory");
    timelockProxy = IGovernanceFactory(governanceFactory).governanceTimelock();

    // Mento Reserve Multisig address:
    reserveMultisig = contracts.dependency("PartialReserveMultisig");

    // Celo Custody Reserve address:
    celoCustodyReserve = address(uint160(contracts.deployed("ReserveProxy")));
  }

  function run() public {
    console.log("\nStarting MU08 checks:");
    prepare();

    // verifyCustodyReserveSetup();
    // verifyReturnOfCelo();

    // verifyMentoReserveFinalSetup();
    verifyTokenOwnership();
    verifyMentoV2Ownership();
    verifyMentoV1Ownership();
    verifyGovernanceFactoryOwnership();
  }

  function verifyCustodyReserveSetup() public {
    console.log("\n== Verifying custody reserve setup: ==");

    // Verify Mento Governance is owner of custody reserve
    address custodyReserveOwner = IOwnableLite(celoCustodyReserve).owner();
    require(
      custodyReserveOwner == timelockProxy,
      "❗️❌ Custody reserve ownership not transferred to Mento Governance"
    );
    console.log("🟢 Custody reserve ownership transferred to Mento Governance");

    // Verify custody reserve implementation
    address custodyReserveImplementation = IProxyLite(celoCustodyReserve)._getImplementation();
    require(
      custodyReserveImplementation == IProxyLite(reserveProxy)._getImplementation(),
      "❗️❌ Custody reserve implementation not set correctly"
    );
    console.log("🟢 Custody reserve implementation set to Reserve implementation");

    // Verify Custody Reserve can't be reinitialized
    vm.expectRevert();
    IReserve(celoCustodyReserve).initialize(
      address(0),
      0,
      0,
      0,
      0,
      new bytes32[](0),
      new uint256[](0),
      0,
      0,
      new address[](0),
      new uint256[](0)
    );
    console.log("🟢 Custody Reserve can't be reinitialized");

    // Verify custody reserve other reserve addresses
    address[] memory otherReserves = IReserve(celoCustodyReserve).getOtherReserveAddresses();
    require(otherReserves.length == 1, "❗️❌ Wrong number of other reserves addresses");
    require(otherReserves[0] == celoGovernance, "❗️❌ Other reserve address is not Celo Governance");
    console.log("🟢 Custody reserve only other reserve address is Celo Governance");

    // Verify custody reserve collateral assets
    address collateralAsset = IReserve(celoCustodyReserve).collateralAssets(0);
    require(collateralAsset == CELOProxy, "❗️❌ Collateral asset is not CELO");
    vm.expectRevert();
    IReserve(celoCustodyReserve).collateralAssets(1);
    console.log("🟢 Custody reserve collateral asset is only CELO");

    // Verify custody reserve spending limits
    uint256 dailySpendingLimit = IReserve(celoCustodyReserve).getDailySpendingRatioForCollateralAsset(collateralAsset);
    require(dailySpendingLimit == 1e24, "❗️❌ Daily spending limit is not 100%");
    console.log("🟢 Custody reserve daily spending limit on CELO is 100%");

    // Verify custody reserve spender is Celo Governance
    require(
      IReserve(celoCustodyReserve).isSpender(celoGovernance),
      "❗️❌ Celo Governance is not a spender on custody reserve"
    );
    console.log("🟢 Celo Governance is a spender on custody reserve");
  }

  function verifyReturnOfCelo() public {
    uint256 fullReturnAmount = 85941499340972869827370586; // 85.9M CELO
    uint256 firstReturnAmount = 20_000_000 * 1e18;
    uint256 remainingReturnAmount = 65941499340972869827370586; // 65.9M CELO

    console.log("\n== Verifying return of 85.9M Celo: ==");

    // Verify custody reserve balance is ~65.9M CELO
    uint256 balance = IERC20(CELOProxy).balanceOf(celoCustodyReserve);
    require(balance == remainingReturnAmount, "❗️❌ Custody reserve balance is not 65.9M CELO");
    console.log("🟢 Custody reserve balance is 65.9M Celo");

    // Verify initial CELO amount was transferred to Celo Governance
    uint256 celoGovernanceBalance = IERC20(CELOProxy).balanceOf(celoGovernance);
    // @dev can't do an exact check because Celo Governance already has some CELO
    require(firstReturnAmount <= celoGovernanceBalance, "❗️❌ Celo Governance balance is less than 20M CELO");
    console.log("🟢 Celo Governance balance is larger than 20M CELO");

    // Verify custody reserve last spending day on collateral asset
    uint256 lastSpend = IReserve(celoCustodyReserve).collateralAssetLastSpendingDay(CELOProxy);
    require(lastSpend == now / 1 days, "❗️❌ Last spend day is not today");

    // Verify Celo governance can pull remaining CELO from custody reserve
    vm.prank(celoGovernance);
    IReserve(celoCustodyReserve).transferCollateralAsset(
      CELOProxy,
      address(uint160(celoGovernance)),
      remainingReturnAmount
    );
    uint256 celoGovernanceBalanceAfter = IERC20(CELOProxy).balanceOf(celoGovernance);
    require(
      celoGovernanceBalanceAfter == celoGovernanceBalance + remainingReturnAmount,
      "❗️❌ Celo Governance can't pull remaining CELO from custody reserve"
    );
    console.log("🟢 Celo Governance can pull remaining CELO from custody reserve");
  }

  function verifyMentoReserveFinalSetup() public {
    console.log("\n== Verifying Mento Reserve final setup: ==");
    // 1. There should only be one other reserve address, which is the Reserve Multisig
    // console.log("\n== Verifying other reserves addresses of onchain Reserve: ==");
    address[] memory otherReserves = IReserve(reserveProxy).getOtherReserveAddresses();

    require(otherReserves.length == 1, "❗️❌ Wrong number of other reserves addresses");
    require(otherReserves[0] == reserveMultisig, "❗️❌ Other reserve address is not the Reserve Multisig");
    console.log("🟢Other reserves address was added successfully: ", reserveMultisig);
    console.log("🤘🏼Other reserves addresses of onchain Reserve are updated correctly.");

    // 2. Mento Reserve multisig can pull the remaining CELO from the Reserve
    uint256 multisigBalanceBefore = IERC20(CELOProxy).balanceOf(reserveMultisig);
    uint256 reserveBalanceBefore = IERC20(CELOProxy).balanceOf(reserveProxy);

    vm.prank(reserveMultisig);
    IReserve(reserveProxy).transferCollateralAsset(CELOProxy, address(uint160(reserveMultisig)), reserveBalanceBefore);

    require(
      IERC20(CELOProxy).balanceOf(reserveMultisig) == multisigBalanceBefore + reserveBalanceBefore,
      "❗️❌ Mento Governance can't pull remaining CELO from Reserve"
    );
    require(
      IERC20(CELOProxy).balanceOf(reserveProxy) == 0,
      "❗️❌ Reserve balance is not 0 after pulling remaining CELO"
    );
    console.log("🟢 Mento Governance can pull remaining CELO from Mento reserve");

    // 3. Mento Governance can act on Custody Reserve if needed.
    require(
      !IReserve(celoCustodyReserve).isSpender(timelockProxy),
      "❗️❌ Mento Governance is a spender on custody reserve before adding it"
    );
    vm.prank(timelockProxy);
    IReserve(celoCustodyReserve).addSpender(timelockProxy);
    require(
      IReserve(celoCustodyReserve).isSpender(timelockProxy),
      "❗️❌ Mento Governance is not a spender on custody reserve after adding it"
    );

    console.log("🟢 Mento Governance can act on custody reserve if needed");
  }

  function verifyTokenOwnership() public {
    console.log("\n== Verifying token proxy and implementation ownership: ==");
    address[] memory tokenProxies = Arrays.addresses(
      cUSDProxy,
      cEURProxy,
      cBRLProxy,
      eXOFProxy,
      cKESProxy,
      PUSOProxy,
      cCOPProxy,
      cGHSProxy,
      cGBPProxy,
      cAUDProxy,
      cCADProxy,
      cZARProxy
    );

    for (uint256 i = 0; i < tokenProxies.length; i++) {
      verifyProxyAndImplementationOwnership(tokenProxies[i]);
    }
    console.log("🤘🏼Token proxies and implementations ownership transferred to Mento Governance🤘🏼");
  }

  function verifyMentoV2Ownership() public {
    console.log("\n== Verifying MentoV2 contract ownerships: ==");
    address[] memory mentoV2Proxies = Arrays.addresses(brokerProxy, biPoolManagerProxy, reserveProxy);
    for (uint256 i = 0; i < mentoV2Proxies.length; i++) {
      verifyProxyAndImplementationOwnership(mentoV2Proxies[i]);
    }
    address[] memory mentoV2NonupgradeableContracts = Arrays.addresses(
      breakerBox,
      medianDeltaBreaker,
      valueDeltaBreaker
    );
    console.log("Verifying MentoV2 nonupgradeable contract ownerships:");
    for (uint256 i = 0; i < mentoV2NonupgradeableContracts.length; i++) {
      verifyNonupgradeableContractsOwnership(mentoV2NonupgradeableContracts[i]);
    }
    console.log("🤘🏼MentoV2 contract ownerships transferred to Mento Governance🤘🏼");
  }

  function verifyMentoV1Ownership() public {
    console.log("\n== Verifying MentoV1 contract ownerships: ==");
    address[] memory mentoV1Proxies = Arrays.addresses(
      exchangeProxy,
      exchangeEURProxy,
      exchangeBRLProxy,
      grandaMentoProxy
    );
    for (uint256 i = 0; i < mentoV1Proxies.length; i++) {
      verifyProxyAndImplementationOwnership(mentoV1Proxies[i]);
    }
    console.log("🤘🏼MentoV1 contract ownerships transferred to Mento Governance🤘🏼");
  }

  function verifyGovernanceFactoryOwnership() public {
    console.log("\n== Verifying GovernanceFactory ownership: ==");
    verifyNonupgradeableContractsOwnership(governanceFactory);
    console.log("🤘🏼GovernanceFactory ownership transferred to Mento Governance🤘🏼");
  }

  function verifyProxyAndImplementationOwnership(address proxy) internal {
    address proxyOwner = IOwnableLite(proxy).owner();
    require(proxyOwner == timelockProxy, "❗️❌ Proxy ownership not transferred to Mento Governance");
    console.log("🟢 Proxy:[%s] ownership transferred to Mento Governance", proxy);

    address proxyAdmin = IProxyLite(proxy)._getOwner();
    require(proxyAdmin == timelockProxy, "❗️❌ Proxy admin ownership not transferred to Mento Governance");
    console.log("🟢 Proxy:[%s] admin ownership transferred to Mento Governance", proxy);

    address implementation = IProxyLite(proxy)._getImplementation();
    address implementationOwner = IOwnableLite(implementation).owner();
    require(implementationOwner != address(0), "❗️❌ Implementation not owned by anybody");

    // Note: Mento V1 contracts are owned by the original deployer address and not by Celo Governance,
    // so we are not able to transfer them. Since they are deprecated anyways we are fine with this.
    if (implementationOwner != timelockProxy && !isMentoV1Contract(proxy)) {
      console.log("🟡 Warning Implementation:[%s] ownership not transferred to Mento Governance 🟡 ", implementation);
    } else if (implementationOwner == timelockProxy) {
      console.log("🟢 Implementation:[%s] ownership transferred to Mento Governance", implementation);
    }
  }

  function isMentoV1Contract(address contractAddr) internal view returns (bool) {
    return
      contractAddr == exchangeProxy ||
      contractAddr == exchangeEURProxy ||
      contractAddr == exchangeBRLProxy ||
      contractAddr == grandaMentoProxy;
  }

  function verifyNonupgradeableContractsOwnership(address nonupgradeableContract) public {
    address contractOwner = IOwnableLite(nonupgradeableContract).owner();
    require(contractOwner == timelockProxy, "❗️❌ Contract ownership not transferred to Mento Governance");
    console.log("🟢 Contract:[%s] ownership transferred to Mento Governance", nonupgradeableContract);
  }
}
