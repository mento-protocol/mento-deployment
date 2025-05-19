// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "celo-foundry/Test.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IChainlinkRelayerFactory } from "mento-core-2.5.0/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";
import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

import { OracleMigrationConfig } from "./Config.sol";

interface ISortedOracles {
  function addOracle(address, address) external;

  function removeOracle(address, address, uint256) external;

  function setEquivalentToken(address, address) external;

  function getEquivalentToken(address) external returns (address);

  function medianRate(address) external returns (uint256, uint256);

  function medianTimestamp(address) external view returns (uint256);

  function getOracles(address) external returns (address[] memory);

  function setTokenReportExpiry(address, uint256) external;

  function getTokenReportExpirySeconds(address) external returns (uint256);

  function tokenReportExpirySeconds(address) external returns (uint256);
}

contract OracleMigration is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;
  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  OracleMigrationConfig private config;

  address private redstoneAdapter;
  address private biPoolManagerProxy;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;

  mapping(address => IChainlinkRelayer) private relayersByRateFeedId;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  function loadDeployedContracts() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
  }

  function setAddresses() public {
    config = new OracleMigrationConfig();
    config.load();

    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    redstoneAdapter = contracts.dependency("RedstoneAdapter");
    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));

    address[] memory relayers = relayerFactory.getRelayers();
    for (uint i = 0; i < relayers.length; i++) {
      IChainlinkRelayer relayer = IChainlinkRelayer(relayers[i]);
      relayersByRateFeedId[relayer.rateFeedId()] = relayer;
    }
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

    address[] memory feedsToMigrate = config.feedsToMigrate();

    // 1. Remove all oracles from the feeds, except for the redstone adapter
    for (uint i = 0; i < feedsToMigrate.length; i++) {
      address identifier = feedsToMigrate[i];
      removeAllOracles(identifier);
    }

    // 2. Whitelist the chainlink relayer for the chainlink powered feeds
    for (uint i = 0; i < feedsToMigrate.length; i++) {
      address identifier = feedsToMigrate[i];
      if (config.isChainlinkPowered(identifier)) {
        whitelistRelayerFor(identifier);
      }
    }
    // Additionally, whitelist relayers for additional feeds that will be used in the next proposal
    // (EUR/USD, BRL/USD, XOF/USD)
    for (uint i = 0; i < config.additionalRelayersToWhitelist().length; i++) {
      address identifier = config.additionalRelayersToWhitelist()[i];
      whitelistRelayerFor(identifier);
    }

    // 3. Set the token report expiry time to 6 minutes for all the feeds being migrated
    uint256 tokenReportExpiry = 6 minutes;
    for (uint i = 0; i < feedsToMigrate.length; i++) {
      address identifier = feedsToMigrate[i];
      setTokenReportExpiry(identifier, tokenReportExpiry);
    }
    // Additionally, set the token report expiry for the additional feeds whitelisted in step 3
    for (uint i = 0; i < config.additionalRelayersToWhitelist().length; i++) {
      address identifier = config.additionalRelayersToWhitelist()[i];
      setTokenReportExpiry(identifier, tokenReportExpiry);
    }
    // PHP/USD was the first feed to use Chainlink, but we set the token report expiry time to 5 minutes back then.
    // We set it to 6 minutes to keep the same frequency as the other feeds.
    setTokenReportExpiry(config.PHPUSDIdentifier(), tokenReportExpiry);

    // 4. Re-create exchanges with a single report
    recreateExchangesWithSingleReport();

    return transactions;
  }

  function whitelistRelayerFor(address rateFeedIdentifier) internal {
    IChainlinkRelayer relayer = relayersByRateFeedId[rateFeedIdentifier];
    require(
      address(relayer) != address(0),
      string(abi.encodePacked("Relayer for rateFeed=", rateFeedIdentifier, " not deployed"))
    );

    transactions.push(
      ICeloGovernance.Transaction({
        value: 0,
        destination: address(sortedOracles),
        data: abi.encodeWithSelector(ISortedOracles(0).addOracle.selector, rateFeedIdentifier, address(relayer))
      })
    );
  }

  function setTokenReportExpiry(address rateFeedIdentifier, uint256 expectedExpiry) internal {
    uint256 currentExpiry = sortedOracles.tokenReportExpirySeconds(rateFeedIdentifier);
    if (currentExpiry != expectedExpiry) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: address(sortedOracles),
          data: abi.encodeWithSelector(
            ISortedOracles(0).setTokenReportExpiry.selector,
            rateFeedIdentifier,
            expectedExpiry
          )
        })
      );
    }
  }

  function recreateExchangesWithSingleReport() internal {
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = exchangeIds.length - 1; i >= 0; i--) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory currentExchange = biPoolManager.getPoolExchange(exchangeId);

      if (!config.shouldRecreateExchange(currentExchange.config.referenceRateFeedID)) {
        require(currentExchange.config.minimumReports == 1, "❌ Expected minimum reports to be 1 on non-migrated feed");
        continue;
      }

      transactions.push(
        ICeloGovernance.Transaction(
          0,
          biPoolManagerProxy,
          abi.encodeWithSelector(IBiPoolManager(0).destroyExchange.selector, exchangeId, i)
        )
      );

      IBiPoolManager.PoolExchange memory newExchange = config.getNewExchangeCfg(currentExchange);

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
    address[] memory oracles = ISortedOracles(sortedOracles).getOracles(rateFeedIdentifier);
    bool isRedstonePowered = config.isRedstonePowered(rateFeedIdentifier);

    if (isRedstonePowered) {
      require(Arrays.contains(oracles, redstoneAdapter), "Redstone adapter not found on redstone powered feed");
    }

    for (uint i = oracles.length - 1; i >= 0; i--) {
      if (oracles[i] != redstoneAdapter) {
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: address(sortedOracles),
            data: abi.encodeWithSelector(ISortedOracles(0).removeOracle.selector, rateFeedIdentifier, oracles[i], i)
          })
        );
      }

      if (i == 0) break;
    }
  }
}
