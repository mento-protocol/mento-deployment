// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
// import { console } from "forge-std/console.sol";
import { console2 as console } from "celo-foundry/Test.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IChainlinkRelayerFactory } from "mento-core-2.5.0/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";
import { IBiPoolManager } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

interface ISortedOracles {
  function addOracle(address, address) external;

  function removeOracle(address, address, uint256) external;

  function setEquivalentToken(address, address) external;

  function getEquivalentToken(address) external returns (address);

  function medianRate(address) external returns (uint256, uint256);

  function getOracles(address) external returns (address[] memory);

  function setTokenReportExpiry(address, uint256) external;

  function getTokenReportExpirySeconds(address) external returns (uint256);

  function tokenReportExpirySeconds(address) external returns (uint256);
}

contract SunsetOracles is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  address private biPoolManagerProxy;

  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address payable private eXOFProxy;
  address payable private cKESProxy;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;

  mapping(address => IChainlinkRelayer) private relayersByRateFeedId;

  address[] private feedsToMigrate;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
    addFeedsToMigrate();
  }

  /**
   * @dev Loads the deployed contracts from previous deployments
   */
  function loadDeployedContracts() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.load("cKES-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");

    contracts.loadSilent("MU01-00-Create-Proxies", "latest"); // BrokerProxy & BiPoolProxy
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest"); // Pricing Modules
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));

    address[] memory relayers = relayerFactory.getRelayers();
    for (uint i = 0; i < relayers.length; i++) {
      IChainlinkRelayer relayer = IChainlinkRelayer(relayers[i]);
      relayersByRateFeedId[relayer.rateFeedId()] = relayer;
    }

    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    cUSDProxy = contracts.celoRegistry("StableToken");
    cEURProxy = contracts.celoRegistry("StableTokenEUR");
    cBRLProxy = contracts.celoRegistry("StableTokenBRL");
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
    cKESProxy = contracts.deployed("StableTokenKESProxy");
  }

  function addFeedsToMigrate() public {
    feedsToMigrate.push(cUSDProxy); // CELO/USD
    feedsToMigrate.push(cEURProxy); // CELO/EUR
    feedsToMigrate.push(cBRLProxy); // CELO/BRL
    feedsToMigrate.push(cKESProxy); // CELO/KES
    feedsToMigrate.push(eXOFProxy); // CELO/XOF

    feedsToMigrate.push(toRateFeedId("USDCUSD"));
    feedsToMigrate.push(toRateFeedId("USDCEUR"));
    feedsToMigrate.push(toRateFeedId("USDCBRL"));

    feedsToMigrate.push(toRateFeedId("USDTUSD"));

    feedsToMigrate.push(toRateFeedId("EUROCEUR"));
    feedsToMigrate.push(toRateFeedId("EUROCXOF"));
    feedsToMigrate.push(toRateFeedId("EURXOF"));

    feedsToMigrate.push(toRateFeedId("KESUSD"));
    feedsToMigrate.push(toRateFeedId("relayed:PHPUSD"));
  }

  function run() public {
    prepare();

    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "changeMePlease", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    for (uint i = 0; i < feedsToMigrate.length; i++) {
      address identifier = feedsToMigrate[i];
      removeAllOracles(identifier);
    }

    uint256 tokenReportExpiry = 6 minutes;
    for (uint i = 0; i < feedsToMigrate.length; i++) {
      address identifier = feedsToMigrate[i];
      proposal_whitelistRelayerFor(identifier, tokenReportExpiry);
    }

    recreateExchangesWithSingleReport();

    return transactions;
  }

  /**
   * @notice For a give rateFeed identifier, see if there's a register deployed relayer
   * and whitelist if so. Additionally, set the report expiry time if needed.
   */
  function proposal_whitelistRelayerFor(address rateFeedIdentifier, uint256 tokenReportExpiry) internal {
    IChainlinkRelayer relayer = relayersByRateFeedId[rateFeedIdentifier];
    require(
      address(relayer) != address(0),
      string(abi.encodePacked("Relayer for rateFeed=", rateFeedIdentifier, " not deployed"))
    );

    // The PHP/USD relayer is already whitelisted, so we don't need to add it again.
    // We only want to set the token report expiry time to 6 minutes, which happens in the next step.
    if (rateFeedIdentifier != toRateFeedId("relayed:PHPUSD")) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: address(sortedOracles),
          data: abi.encodeWithSelector(ISortedOracles(0).addOracle.selector, rateFeedIdentifier, address(relayer))
        })
      );
    }

    uint256 currentExpiry = sortedOracles.tokenReportExpirySeconds(rateFeedIdentifier);
    if (currentExpiry != tokenReportExpiry) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: address(sortedOracles),
          data: abi.encodeWithSelector(
            ISortedOracles(0).setTokenReportExpiry.selector,
            rateFeedIdentifier,
            tokenReportExpiry
          )
        })
      );
    }
  }

  function shouldBeMigrated(address rateFeedIdentifier) internal returns (bool) {
    return Arrays.contains(feedsToMigrate, rateFeedIdentifier);
  }

  function recreateExchangesWithSingleReport() internal {
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = exchangeIds.length - 1; i >= 0; i--) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory currentExchange = biPoolManager.getPoolExchange(exchangeId);

      if (!shouldBeMigrated(currentExchange.config.referenceRateFeedID)) {
        continue;
      }

      // Delete the exchange
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          biPoolManagerProxy,
          abi.encodeWithSelector(IBiPoolManager(0).destroyExchange.selector, exchangeId, i)
        )
      );

      // Re-create the exchange
      IBiPoolManager.PoolExchange memory newExchange = currentExchange;
      newExchange.bucket0 = 0;
      newExchange.bucket1 = 0;
      newExchange.lastBucketUpdate = 0;
      newExchange.config.minimumReports = 1;
      newExchange.config.referenceRateResetFrequency = 6 minutes;

      transactions.push(
        ICeloGovernance.Transaction(
          0,
          biPoolManagerProxy,
          abi.encodeWithSelector(IBiPoolManager(0).createExchange.selector, newExchange)
        )
      );

      if (i == 0) break;
    }
  }

  function removeAllOracles(address rateFeedIdentifier) internal {
    // PHP/USD is already using Chainlink, so there's no need to remove and re-add the oracle.
    // We just want to update the pool to have a 6min reset frequency,
    if (rateFeedIdentifier == toRateFeedId("relayed:PHPUSD")) {
      return;
    }

    address[] memory oracles = ISortedOracles(sortedOracles).getOracles(rateFeedIdentifier);
    for (uint i = oracles.length - 1; i >= 0; i--) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: address(sortedOracles),
          data: abi.encodeWithSelector(ISortedOracles(0).removeOracle.selector, rateFeedIdentifier, oracles[i], i)
        })
      );

      if (i == 0) break;
    }
  }
}
