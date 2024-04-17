// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase, max-line-length
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { stdJson } from "forge-std/StdJson.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

contract MUGOV is IMentoUpgrade, GovernanceScript {
  ICeloGovernance.Transaction[] private transactions;
  bytes32 private markleRoot;

  bool public hasChecks = true;

  function prepare() public {
    loadDeployedContracts();
  }

  /**
   * @dev Loads the deployed contracts from the previous deployment step
   */
  function loadDeployedContracts() public {
    contracts.load("MUGOV-00-Create-Factory", "latest");
  }

  function run() public {
    prepare();
    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "MUGOV", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    IGovernanceFactory.MentoTokenAllocationParams memory allocationParams = getTokenAllocationParams();

    address mentoGovernanceFactory = contracts.deployed("GovernanceFactory");
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        mentoGovernanceFactory,
        abi.encodeWithSelector(
          IGovernanceFactory(0).createGovernance.selector,
          contracts.dependency("WatchdogMultisig"), // @TODO: Update final address in deps.json
          readAirgrabMerkleRoot(),
          contracts.dependency("FractalSigner"),
          allocationParams
        )
      )
    );

    return transactions;
  }

  function getTokenAllocationParams() internal returns (IGovernanceFactory.MentoTokenAllocationParams memory) {
    // ================================ MENTO TOKEN ALLOCATION ================================
    // 1. Mento community Treasury (40% 10year emission, 5% immediately available)        (45%)
    // 2. Mento Labs Team, Investors, Future Hires, Advisors                              (30%)
    // 3. Mento Liquidity Support                                                         (10%)
    // 4. Airdrop to Celo and Mento stable assets users                                   (5%)
    // 5. Airdrop to Celo Community Treasury                                              (5%)
    // 6. Mento Reserve Safety Fund                                                       (5%)

    IGovernanceFactory.MentoTokenAllocationParams memory params;

    params.additionalAllocationRecipients = Arrays.addresses(
      contracts.dependency("MentoLabsMultisig"), // #2, Mento Labs Team. @TODO: Update final recipient in deps.json
      contracts.dependency("MentoLiquiditySupport"), // #3, Liquidity Support. @TODO: Update final recipient in deps.json
      contracts.dependency("CeloCommunityTreasury"), // #5, Celo Community Treasury. @TODO: Update final recipient in deps.json
      contracts.celoRegistry("Reserve") // #6, Reserve Safety Fund.
    );
    params.additionalAllocationAmounts = Arrays.uints(300, 100, 50, 50);

    // #4, Community Airdrop
    params.airgrabAllocation = 50;

    // #1, Mento Community Treasury.
    // Note that below we only allocate the 5% part for immediate use that goes to governanceTimeLock.
    // The reimaining part of the allocation (40%) is automatically allocated to the Emission contract
    // by MentoToken.sol during initialization.
    params.mentoTreasuryAllocation = 50;

    return params;
  }

  function readAirgrabMerkleRoot() internal view returns (bytes32) {
    string memory network = Chain.rpcToken(); // celo | baklava | alfajores
    string memory root = vm.projectRoot();
    string memory path = string(abi.encodePacked(root, "/data/airgrab.", network, ".tree.json"));
    string memory json = vm.readFile(path);
    return stdJson.readBytes32(json, ".root");
  }
}
