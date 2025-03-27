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

/**
 forge script {file} --rpc-url $ALFAJORES_RPC_URL 
                     --broadcast --legacy 
 * @dev depends on: ../deploy/*.sol
 * @dev Script to whitelist the FX stable tokens relayers via Celo Governance
 */
contract FX00 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;
  address private cAUD;
  address private cCAD;
  address private cCHF;
  address private cGBP;
  address private cZAR;

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
    contracts.loadSilent("FX00-00-Deploy-Proxys", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    cAUD = contracts.deployed("StableTokenAUDProxy");
    cCAD = contracts.deployed("StableTokenCADProxy");
    cCHF = contracts.deployed("StableTokenCHFProxy");
    cGBP = contracts.deployed("StableTokenGBPProxy");
    cZAR = contracts.deployed("StableTokenZARProxy");

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
      createProposal(_transactions, "TODO", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    uint256 tokenReportExpiry = 6 minutes;

    // AUD
    proposal_whitelistRelayerFor("relayed:CELOAUD", tokenReportExpiry);
    proposal_whitelistRelayerFor("relayed:AUDUSD", tokenReportExpiry);
    proposal_setEquivalentToken(cAUD, "relayed:CELOAUD");

    // CAD
    proposal_whitelistRelayerFor("relayed:CELOCAD", tokenReportExpiry);
    proposal_whitelistRelayerFor("relayed:CADUSD", tokenReportExpiry);
    proposal_setEquivalentToken(cCAD, "relayed:CELOCAD");

    // CHF
    proposal_whitelistRelayerFor("relayed:CELOCHF", tokenReportExpiry);
    proposal_whitelistRelayerFor("relayed:CHFUSD", tokenReportExpiry);
    proposal_setEquivalentToken(cCHF, "relayed:CELOCHF");

    // GBP
    proposal_whitelistRelayerFor("relayed:CELOGBP", tokenReportExpiry);
    proposal_whitelistRelayerFor("relayed:GBPUSD", tokenReportExpiry);
    proposal_setEquivalentToken(cGBP, "relayed:CELOGBP");

    // ZAR
    proposal_whitelistRelayerFor("relayed:CELOZAR", tokenReportExpiry);
    proposal_whitelistRelayerFor("relayed:ZARUSD", tokenReportExpiry);
    proposal_setEquivalentToken(cZAR, "relayed:CELOZAR");

    return transactions;
  }

  /**
   * @notice For a give rateFeed string, see if there's a register deployed relayer, and ensure
   * it is the only whitelisted oracle for that rate feed.
   * If there are multiple oracles whitelisted, remove them.
   * If the existing relayer isn't whitelisted, add it.
   */
  function proposal_whitelistRelayerFor(string memory rateFeed, uint256 tokenReportExpiry) private {
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
      uint256 currentExpiry = sortedOracles.tokenReportExpirySeconds(rateFeedId);
      if (currentExpiry != tokenReportExpiry) {
        transactions.push(
          ICeloGovernance.Transaction({
            value: 0,
            destination: address(sortedOracles),
            data: abi.encodeWithSelector(ISortedOracles(0).setTokenReportExpiry.selector, rateFeedId, tokenReportExpiry)
          })
        );
      }
    }
  }

  /**
   * @notice Sorted Oracles has this new feature of equivalent tokens. When a token has an
   * equivalent token configured, SortedOracles will return the equivalent token's median
   * rate when asked. This was used for gas payments with USDC, by setting USDC's equivalent
   * token to be cUSD. But this also allows us to remove this duality between rate feeds that
   * are tokens, and rate feeds derived from identifiers.
   * In the context of a token address it means that we can report to the rateFeed defined by the
   * canonical id: `relayed:CELOXXX`, and then have the token address point to that for
   * gas payments.
   */
  function proposal_setEquivalentToken(address token, string memory rateFeed) private {
    address rateFeedId = toRateFeedId(rateFeed);
    transactions.push(
      ICeloGovernance.Transaction({
        value: 0,
        destination: address(sortedOracles),
        data: abi.encodeWithSelector(ISortedOracles(0).setEquivalentToken.selector, token, rateFeedId)
      })
    );
  }
}
