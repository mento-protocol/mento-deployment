// SPDX-License-Identifier: UNLICENSED
// solhint-disable func-name-mixedcase, contract-name-camelcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { FixidityLib } from "mento-core/contracts/common/FixidityLib.sol";
import { ICeloGovernance } from "mento-core/contracts/governance/interfaces/ICeloGovernance.sol";
import { IBiPoolManager } from "mento-core/contracts/interfaces/IBiPoolManager.sol";
import { IPricingModule } from "mento-core/contracts/interfaces/IPricingModule.sol";
import { IReserve } from "mento-core/contracts/interfaces/IReserve.sol";
import { IRegistry } from "mento-core/contracts/common/interfaces/IRegistry.sol";
import { Proxy } from "mento-core/contracts/common/Proxy.sol";

/**
 forge script {file} --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy 
                     --private-key $BAKLAVA_MENTO_PROPOSER
 * @dev Initial CGP (./baklava.sol) had a mistake in the bucket sizes.
 */
contract MentoUpgrade1_baklava_rev2 is GovernanceScript {
  ICeloGovernance.Transaction[] private transactions;

  function run() public {
    contracts.load("00-CircuitBreaker", "1673625499");
    contracts.load("01-Broker", "1673625757");
    address governance = contracts.celoRegistry("Governance");

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "TODO", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    address cUSDProxy = contracts.celoRegistry("StableToken");
    address cUSDImpl = contracts.deployed("StableToken");
    address cEURProxy = contracts.celoRegistry("StableTokenEUR");
    address cEURImpl = contracts.deployed("StableTokenEUR");

    // TODO: Commented out as BRL is not yet deployed on baklava.
    // address cBRLProxy = contracts.celoRegistry("StableTokenBRL");
    // address cBRLImpl = contracts.deployed("StableTokenBRL");

    transactions.push(
      ICeloGovernance.Transaction(0, cUSDProxy, abi.encodeWithSelector(Proxy(0)._setImplementation.selector, cUSDImpl))
    );

    transactions.push(
      ICeloGovernance.Transaction(0, cEURProxy, abi.encodeWithSelector(Proxy(0)._setImplementation.selector, cEURImpl))
    );

    // TODO: Commented out as BRL is not yet deployed on baklava.
    // transactions.push(
    //   ICeloGovernance.Transaction(0, cBRLProxy,
    // abi.encodeWithSelector(Proxy(0)._setImplementation.selector, cBRLImpl))
    // );
    return transactions;
  }
}
