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
    contracts.load("MUGOV-04-Create-Factory", "latest");
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
    IGovernanceFactory.MentoTokenAllocationParams memory allocationParams;
    allocationParams.airgrabAllocation = 100;
    allocationParams.mentoTreasuryAllocation = 100;
    if (Chain.isCelo()) {
      // TODO: Add final allocation amounts
      allocationParams.additionalAllocationRecipients = Arrays.addresses(contracts.dependency("MentoLabsMultisig"));
      allocationParams.additionalAllocationAmounts = Arrays.uints(100);
    } else {
      allocationParams.additionalAllocationRecipients = Arrays.addresses(
        contracts.dependency("MentoLabsMultisig"),
        /// @dev This is a tesetnet only allocation.
        /// Whenever we deploy to testnets we seed these addresses with $MENTO.
        /// The arguments to vm.addr are the private keys, and the addresses are in the comment.
        /// You can import one of these private keys into metamask to use for testing.
        vm.addr(0xb228ca748093e781f324701f53cfa26b26bc55919e0fe361d704b9c2a3d9817c), // 0x99995570bc88340d726D15D172e668271FBC9e20
        vm.addr(0x6deca5973d3a26e5ee93e60ade2e7568072471711909a87e26afcec346dbf9da), // 0x9999f469Fa49bB921eA385F1de49dcBccfbC9A82
        vm.addr(0x648f06647a69623eb01ce413890fc7c907bf2d36e3a4e7dbc9fd3adc8162f542), // 0x9999700347b57a3152E8B63123649949A9aBE20d
        vm.addr(0x2a5e23ad202f6dcc13847c68a85b26ee7b26a5e89a89cc9a19f15d46932fc5da), // 0x9999db67bF5151668AAff29eD4BAca3926747ED7
        vm.addr(0x50a5d71e8994f5f4bb44e8431f695ed1520cf1999b6d01c4a6fd199f14a6c747), // 0x9999C6De88eBdf0aff022D127C36541D53F8789A
        vm.addr(0x6ccf3ccc08dabc44678a688815e2d2e8603416c886eb550c2be2319423be518c), // 0x99994874b3B90E690287C85df1ba26E886FF87f0
        vm.addr(0xef7301ce9a7e88105c539f96c53e5cf70cff0c21ffae34c088febe6cf00696b1) //  0x99990eA09DD56949DbaFe97fc34DBC69BDA81027
      );
      allocationParams.additionalAllocationAmounts = Arrays.uints(100, 1, 1, 1, 1, 1, 1, 1);
    }

    address mentoGovernanceFactory = contracts.deployed("GovernanceFactory");
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        mentoGovernanceFactory,
        abi.encodeWithSelector(
          IGovernanceFactory(0).createGovernance.selector,
          contracts.dependency("WatchdogMultisig"),
          contracts.celoRegistry("Governance"),
          readAirgrabMerkleRoot(),
          contracts.dependency("FractalSigner"),
          allocationParams
        )
      )
    );

    return transactions;
  }

  function readAirgrabMerkleRoot() internal view returns (bytes32) {
    string memory network = Chain.rpcToken(); // celo | baklava | alfajores
    string memory root = vm.projectRoot();
    string memory path = string(abi.encodePacked(root, "/data/airgrab.", network, ".tree.json"));
    string memory json = vm.readFile(path);
    return stdJson.readBytes32(json, ".root");
  }
}
