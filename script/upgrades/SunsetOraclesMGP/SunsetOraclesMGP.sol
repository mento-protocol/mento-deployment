// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Chain } from "script/utils/mento/Chain.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/*

===== Rough tech plan



=== Feeds that are only powered by mlabs oracles:
    1. Deploy Chainlink relayers for all of them

    2. Whitelist Chainlink relayers
        Use legacy ratefeed id's, in order to not need to re-configure circuit breakers

    3. Destroy and re-create exchanges to be replaced (MGP)
        Maybe needs some sort of config/function that given an asset pair, it searches for 
        that exchange, reads all the current on-chain parameters, and deletes the exchange
        and re-creates it with the exact same parameters, except for:
            minimumReports = 1. 
            rateFeedResetFrequency = 6 mins?

        q: watch out for the deletion index, maybe needs to be done in reverse to not alter the
        order of the original list.

    4. Deploy new relayers, shutdown our clients
        Because of mocks on testnets, we need some sort of way of relaying the actual mainnet price often.
        We don't want to be stuck on old prices on Alfajores.

        Brainstorm
            Run the existing UpdateMockChainlinkAggregator script in a VM within a cron job
            create a contract with a fn relayAll(aggregators[], answers[]) that calls all of them in a single tx


    5. Remove our oracles from the whitelist in future CGP

=== Feeds that are powered by mlabs, chainlink and previously DT
    1. CGP to remove DT from the whitelist, probably together with CGP to whitelist new chainlink relayers

    2. MGP to destroy and re-create exchanges to be replaced
        minimumReports = 1, rateFeedResetFreq = 6 mins

    3. Shutdown our clients, so only Redstone reports
    4. Remove our oracles from the whitelist in future CGP
*/

contract SunsetOracles is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  address public mentoGovernor;

  IGovernanceFactory public governanceFactory;

  /**
   * @dev Loads the contracts from previous deployments
   */
  function loadDeployedContracts() public {
    // Load load deployment with governance factory
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");

    // Load the deployed ProxyAdmin contract
    contracts.loadSilent("MU09-Deploy-LockingProxyAdmin", "latest");
  }

  function prepare() public {
    loadDeployedContracts();

    address governanceFactoryAddress = contracts.deployed("GovernanceFactory");
    governanceFactory = IGovernanceFactory(governanceFactoryAddress);
    mentoGovernor = governanceFactory.mentoGovernor();
  }

  function recreateExchange(address asset0, address asset1) internal {
    // Locate exchange with both assets
    // Get all the configuration: PoolExchange & PoolConfig
    // Delete old and re-create with new params
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    recreateExchange(address(0), address(0));

    return transactions;
  }
}
