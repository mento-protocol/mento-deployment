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
contract FX02 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;
  address private cJPY;
  address private cNGN;

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
    contracts.loadSilent("FX02-00-Deploy-Proxys", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    cJPY = contracts.deployed("StableTokenJPYProxy");
    cNGN = contracts.deployed("StableTokenNGNProxy");

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
      createProposal(_transactions, "todo", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    uint256 tokenReportExpiry = 6 minutes;

    // cJPY
    proposal_whitelistRelayerFor("relayed:CELOJPY", tokenReportExpiry);
    proposal_whitelistRelayerFor("relayed:JPYUSD", tokenReportExpiry);
    proposal_setEquivalentToken(cJPY, "relayed:CELOJPY");

    // cNGN
    proposal_whitelistRelayerFor("relayed:CELONGN", tokenReportExpiry);
    proposal_whitelistRelayerFor("relayed:NGNUSD", tokenReportExpiry);
    proposal_setEquivalentToken(cNGN, "relayed:CELONGN");
    return transactions;
  }

  function proposal_whitelistRelayerFor(string memory rateFeed, uint256 tokenReportExpiry) private {
    address rateFeedId = toRateFeedId(rateFeed);
    IChainlinkRelayer relayer = relayersByRateFeedId[rateFeedId];
    require(
      address(relayer) != address(0),
      string(abi.encodePacked("Relayer for rateFeed=", rateFeed, " not deployed"))
    );

    address[] memory oracles = sortedOracles.getOracles(rateFeedId);
    require(oracles.length == 0, "Expected no existing oracles for rateFeed");
    transactions.push(
      ICeloGovernance.Transaction({
        value: 0,
        destination: address(sortedOracles),
        data: abi.encodeWithSelector(ISortedOracles(0).addOracle.selector, rateFeedId, address(relayer))
      })
    );

    uint256 currentExpiry = sortedOracles.tokenReportExpirySeconds(rateFeedId);
    require(currentExpiry != tokenReportExpiry, "Token report expiry already set for rateFeed");
    transactions.push(
      ICeloGovernance.Transaction({
        value: 0,
        destination: address(sortedOracles),
        data: abi.encodeWithSelector(ISortedOracles(0).setTokenReportExpiry.selector, rateFeedId, tokenReportExpiry)
      })
    );
  }

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
