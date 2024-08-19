// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console } from "forge-std/Console.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IChainlinkRelayerFactory } from "lib/mento-core-develop/contracts/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "lib/mento-core-develop/contracts/interfaces/IChainlinkRelayer.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

interface ISortedOracles {
  function addOracle(address, address) external;

  function removeOracle(address, address, uint256) external;

  function setEquivalentToken(address, address) external;

  function getEquivalentToken(address) external returns (address);

  function getOracles(address) external returns (address[] memory);
}

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 */
contract MU07 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  // Mento contracts
  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;
  address private PSO;

  mapping(address => IChainlinkRelayer) relayersByRateFeedId;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  /**
   * @dev Loads the deployed contracts from previous deployments
   */
  function loadDeployedContracts() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.loadSilent("PSO-00-Create-Proxies", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    PSO = contracts.deployed("StableTokenPSOProxy");

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
      createProposal(_transactions, "whitelist-oracles", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    proposal_whitelistRelayerFor("relayed:CELOPHP");
    proposal_whitelistRelayerFor("relayed:PHPUSD");
    proposal_setEquivalentTokenForPSO();

    return transactions;
  }

  /**
   * @notice For a give rateFeed string, see if there's a register deployed relayer, and ensure
   * it is the only whitelisted oracle for that rate feed.
   * If there are multiple oracles whitelisted, remove them.
   * If the existing relayer isn't whitelisted, add it.
   */
  function proposal_whitelistRelayerFor(string memory rateFeed) private {
    address rateFeedId = toRateFeedId(rateFeed);
    IChainlinkRelayer relayer = relayersByRateFeedId[rateFeedId];
    require(
      address(relayer) != address(0),
      string(abi.encodePacked("Relayer for rateFeed=", rateFeed, " not deployed"))
    );

    address[] memory oracles = sortedOracles.getOracles(rateFeedId);
    bool isOracle = false;

    for (uint i = 0; i < oracles.length; i++) {
      isOracle = isOracle || (oracles[i] == address(relayer));
      if (oracles[i] == address(relayer)) continue;

      // Remove other whitelisted relayers
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: address(sortedOracles),
          data: abi.encodeWithSelector(ISortedOracles(0).removeOracle.selector, rateFeedId, oracles[i], i)
        })
      );
    }

    if (!isOracle) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: address(sortedOracles),
          data: abi.encodeWithSelector(ISortedOracles(0).addOracle.selector, rateFeedId, address(relayer))
        })
      );
    }
  }

  /**
   * @notice Sorted Oracles has this new feature of equivalent tokens. When a token has an
   * equivalent token configured, SortedOracles will return the equivalent token's median
   * rate when asked. This was used for gas payments with USDC, by setting USDC's equivalent
   * token to be cUSD. But this also allows us to remove this duality between rate feeds that
   * are tokens, and rate feeds derived from identifiers.
   * In the context of PSO it means that we can report to the rateFeed defined by the
   * cannonical id: `relayed:CELOPHP`, and then have address(PSO) point to that for
   * gas payments.
   */
  function proposal_setEquivalentTokenForPSO() private {
    address CELOPHPRateFeedId = toRateFeedId("relayed:CELOPHP");
    transactions.push(
      ICeloGovernance.Transaction({
        value: 0,
        destination: contracts.celoRegistry("SortedOracles"),
        data: abi.encodeWithSelector(ISortedOracles(0).setEquivalentToken.selector, PSO, CELOPHPRateFeedId)
      })
    );
  }
}
