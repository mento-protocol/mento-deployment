// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Vm } from "forge-std/Vm.sol";

library Chain {
  address private constant VM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));
  // solhint-disable-next-line const-name-snakecase
  Vm public constant vm = Vm(VM_ADDRESS);

  uint256 public constant NETWORK_ANVIL = 0;

  uint256 public constant NETWORK_CELO_CHAINID = 42220;
  string public constant NETWORK_CELO_CHAINID_STRING = "42220";
  string public constant NETWORK_CELO_RPC = "celo";
  string public constant NETWORK_CELO_PK_ENV_VAR = "MENTO_DEPLOYER_PK";

  uint256 public constant NETWORK_ALFAJORES_CHAINID = 44787;
  string public constant NETWORK_ALFAJORES_CHAINID_STRING = "44787";
  string public constant NETWORK_ALFAJORES_RPC = "alfajores";
  string public constant NETWORK_ALFAJORES_PK_ENV_VAR = "ALFAJORES_DEPLOYER_PK";

  /**
   * @notice Get the current chainId
   * @return the chain id
   */
  function id() internal pure returns (uint256 _chainId) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      _chainId := chainid
    }
  }

  function idString() internal pure returns (string memory) {
    uint256 _chainId = id();
    if (_chainId == NETWORK_CELO_CHAINID) return NETWORK_CELO_CHAINID_STRING;
    if (_chainId == NETWORK_ALFAJORES_CHAINID) return NETWORK_ALFAJORES_CHAINID_STRING;
    revert("unexpected network");
  }

  function rpcToken() internal pure returns (string memory) {
    uint256 _chainId = id();
    if (_chainId == NETWORK_CELO_CHAINID) return NETWORK_CELO_RPC;
    if (_chainId == NETWORK_ALFAJORES_CHAINID) return NETWORK_ALFAJORES_RPC;
    revert("unexpected network");
  }

  function deployerPrivateKey() internal view returns (uint256) {
    uint256 _chainId = id();
    if (_chainId == NETWORK_CELO_CHAINID) return vm.envUint(NETWORK_CELO_PK_ENV_VAR);
    if (_chainId == NETWORK_ALFAJORES_CHAINID) return vm.envUint(NETWORK_ALFAJORES_PK_ENV_VAR);
    revert("unexpected network");
  }

  function deployerAddr() internal view returns (address payable) {
    return address(uint160(vm.addr(deployerPrivateKey())));
  }

  /**
   * @notice Setup a fork environment for the current chain
   */
  function fork() internal {
    uint256 forkId = vm.createFork(rpcToken());
    vm.selectFork(forkId);
  }

  function isCelo() internal pure returns (bool) {
    return id() == NETWORK_CELO_CHAINID;
  }

  function isAlfajores() internal pure returns (bool) {
    return id() == NETWORK_ALFAJORES_CHAINID;
  }
}
