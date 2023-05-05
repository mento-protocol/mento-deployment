// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Config } from "./Config.sol";

import { GovernanceScript } from "script/utils/Script.sol";
import { ICGPBuilder } from "script/utils/ICGPBuilder.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { ICeloGovernance } from "mento-core/contracts/governance/interfaces/ICeloGovernance.sol";
import { Proxy } from "mento-core/contracts/common/Proxy.sol";
import { BiPoolManager } from "mento-core/contracts/BiPoolManager.sol";

contract MU01_CGP_Phase1_Patch1 is ICGPBuilder, GovernanceScript {
  ICeloGovernance.Transaction[] private transactions;

  address private cUSD;
  address private cEUR;
  address private cBRL;
  address private celo;
  address private bridgedUSDC;

  address private biPoolManagerProxyAddress;

  /**
   * @dev Runs neccesary functions to prepare data needed to generate transactions
   */
  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  /**
   * @dev Loads the addresses of the contracts needed that were deployed in the previous script
   */
  function loadDeployedContracts() public {
    contracts.load("MU01-00-Create-Proxies", "latest");
    contracts.load("MU01-04-Deploy-BiPoolMananager", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    cBRL = contracts.celoRegistry("StableTokenBRL");
    celo = contracts.celoRegistry("GoldToken");
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    biPoolManagerProxyAddress = contracts.deployed("BiPoolManagerProxy");
  }

  function run() public {
    prepare();
    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "MU01", governance);
    }
    vm.stopBroadcast();
  }

  /**
   * @dev Calls the functions needed to generate transactions for the proposal
   */
  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    proposal_updateBiPoolManagerImplementation();
    proposal_setTokenPrecisionMultipliers();

    return transactions;
  }

  function proposal_updateBiPoolManagerImplementation() public {
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxyAddress,
        abi.encodeWithSelector(Proxy(0)._setImplementation.selector, contracts.deployed("BiPoolManager"))
      )
    );
  }

  function proposal_setTokenPrecisionMultipliers() public {
    address[] memory tokens = Arrays.addresses(cUSD, cEUR, cBRL, celo, bridgedUSDC);
    uint256[] memory multipliers = Arrays.uints(1, 1, 1, 1, 1e12);

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        biPoolManagerProxyAddress,
        abi.encodeWithSelector(BiPoolManager(0).setTokenPrecisionMultipliers.selector, tokens, multipliers)
      )
    );
  }
}
