// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console } from "forge-std/console.sol";

import { Vm } from "forge-std/Vm.sol";
import { Chain } from "./Chain.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { IRegistry } from "script/interfaces/IRegistry.sol";

library Contracts {
  using stdJson for string;

  address private constant REGISTRY_ADDRESS = 0x000000000000000000000000000000000000ce10;
  // solhint-disable-next-line const-name-snakecase
  IRegistry private constant registry = IRegistry(REGISTRY_ADDRESS);

  address private constant VM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));
  // solhint-disable-next-line const-name-snakecase
  Vm private constant vm = Vm(VM_ADDRESS);

  bytes32 private constant CREATE_HASH = 0x14feaf0665b390ef0561125746780cd06c1876ebed7339648fad78cd5fb754ed;

  struct Cache {
    mapping(bytes32 => address) contractAddress;
    bool _dependenciesLoaded;
    string _dependencies;
  }

  function loadUpgrade(Cache storage self, string memory upgrade) internal {
    load(self, string(abi.encodePacked(upgrade, "-00-Create-Proxies")), "latest");
    load(self, string(abi.encodePacked(upgrade, "-01-Create-Nonupgradeable-Contracts")), "latest");
    load(self, string(abi.encodePacked(upgrade, "-02-Create-Implementations")), "latest");
  }

  function load(Cache storage self, string memory script, string memory timestamp) internal {
    _load(self, script, timestamp, false);
  }

  function loadSilent(Cache storage self, string memory script, string memory timestamp) internal {
    _load(self, script, timestamp, true);
  }

  function _load(Cache storage self, string memory script, string memory timestamp, bool silent) internal {
    string memory chainId = Chain.idString();
    string memory root = vm.projectRoot();
    string memory path = string(
      abi.encodePacked(root, "/broadcast/", script, ".sol/", chainId, "/", "run-", timestamp, ".json")
    );
    string memory json = vm.readFile(path);
    /**
     * note(bogdan): Decoding this isn't straightforwad because we're using
     * an old solidity version which affects in two ways:
     * (a) We can't use the latest forge-std helper scripts
     * (b) There's a weird behaviour with decoding nested dynamic types
     * In order to counteract this I'm jumping through hoops a bit.
     * todo(bogdan): Remove all this once we update solidity.
     */

    bytes memory contractAddressesRaw = json.parseRaw(".transactions[*].contractAddress");

    address[] memory contractAddresses;
    if (contractAddressesRaw.length == 32) {
      contractAddresses = new address[](1);
      contractAddresses[0] = abi.decode(contractAddressesRaw, (address));
    } else {
      contractAddresses = abi.decode(contractAddressesRaw, (address[]));
    }

    for (uint256 i = 0; i < contractAddresses.length; i++) {
      string memory stringIndex = uintToString(i);

      string memory txType = abi.decode(
        json.parseRaw(string(abi.encodePacked(".transactions[", stringIndex, "].transactionType"))),
        (string)
      );
      if (keccak256(bytes(txType)) == keccak256(bytes("CREATE"))) {
        string memory contractName = abi.decode(
          json.parseRaw(string(abi.encodePacked(".transactions[", stringIndex, "].contractName"))),
          (string)
        );

        // todo(bogdan): think about best way to handle overrides
        self.contractAddress[keccak256(bytes(contractName))] = contractAddresses[i];

        if (!silent) {
          console.log("Loaded contract %s at %s", contractName, contractAddresses[i]);
        }
      }
    }
  }

  function deployed(Cache storage self, string memory contractName) internal view returns (address payable addr) {
    addr = address(uint160(self.contractAddress[keccak256(bytes(contractName))]));
    require(
      addr != address(0),
      string(abi.encodePacked(contractName, ":NotFoundInDeployedCache:Check relevant deployemnt script was loaded"))
    );
  }

  function celoRegistry(Cache storage, string memory contractName) internal view returns (address) {
    return registry.getAddressForStringOrDie(contractName);
  }

  function _loadDependencies(Cache storage self) internal returns (Cache storage) {
    string memory root = vm.projectRoot();
    string memory path = string(abi.encodePacked(root, "/script/upgrades/dependencies.json"));
    self._dependenciesLoaded = true;
    self._dependencies = vm.readFile(path);
    return self;
  }

  function dependency(Cache storage self, string memory contractName) internal returns (address) {
    if (!self._dependenciesLoaded) _loadDependencies(self);
    string memory chainId = Chain.idString();
    bytes memory contractAddressRaw = self._dependencies.parseRaw(
      // solhint-disable-next-line quotes
      string(abi.encodePacked('["', chainId, '"]', '["', contractName, '"]'))
    );

    require(contractAddressRaw.length == 32, "dependency missing or invalid");
    return abi.decode(contractAddressRaw, (address));
  }

  /// @notice converts number to string
  /// @dev source: https://github.com/provable-things/ethereum-api/blob/master/oraclizeAPI_0.5.sol#L1045
  /// @param _i integer to convert
  /// @return _uintAsString
  function uintToString(uint256 _i) internal pure returns (string memory _uintAsString) {
    uint256 number = _i;
    if (number == 0) {
      return "0";
    }
    uint256 j = number;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len - 1;
    while (number != 0) {
      bstr[k--] = bytes1(uint8(48 + (number % 10)));
      number /= 10;
    }
    return string(bstr);
  }
}
