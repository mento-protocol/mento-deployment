// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console } from "forge-std/console.sol";
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

  address payable private cUSDProxy;
  address payable private cEURProxy;
  address payable private cBRLProxy;

  address payable private cKESProxy;
  address payable private eXOFProxy;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;

  mapping(address => IChainlinkRelayer) private relayersByRateFeedId;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
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
    cUSDProxy = contracts.deployed("StableTokenUSDProxy");
    cEURProxy = contracts.deployed("StableTokenEURProxy");
    cBRLProxy = contracts.deployed("StableTokenBRLProxy");
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

    // 6 minutes to be consistent with other Chainlink relayers because of the time in between
    // Chainlink reporting a new price and us relaying it to SortedOracles.
    uint256 tokenReportExpiry = 6 minutes;

    address[] memory feeds = Arrays.addresses(
      cKESProxy, // CELO/KES relayer
      toRateFeedId("KESUSD"),
      eXOFProxy, // CELO/XOF relayer
      toRateFeedId("EURCXOF"),
      toRateFeedId("EURXOF"),
      toRateFeedId("USDTUSD")
    );

    for (uint i = 0; i < feeds.length; i++) {
      proposal_whitelistRelayerFor(feeds[i], tokenReportExpiry);
      proposal_removeDTOracles();
    }

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

    transactions.push(
      ICeloGovernance.Transaction({
        value: 0,
        destination: address(sortedOracles),
        data: abi.encodeWithSelector(ISortedOracles(0).addOracle.selector, rateFeedIdentifier, address(relayer))
      })
    );

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

  function recreateExchangeWithSingleReport(address asset0, address asset1) internal {
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = exchangeIds.length - 1; i >= 0; i--) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory currentExchange = biPoolManager.getPoolExchange(exchangeId);
      if (currentExchange.asset0 != asset0 || currentExchange.asset1 != asset1) {
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

  function removeAllOracles(string memory rateFeed) internal {
    address[] memory oracles = ISortedOracles(sortedOracles).getOracles(toRateFeedId(rateFeed));
    for (uint i = oracles.length - 1; i >= 0; i--) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: address(sortedOracles),
          data: abi.encodeWithSelector(ISortedOracles(0).removeOracle.selector, rateFeed, oracles[i], i)
        })
      );

      if (i == 0) break;
    }
  }
}
