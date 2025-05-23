// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.13 <0.9.0;

library Arrays {
  function uints(uint256 e0) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](1);
    arr[0] = e0;
    return arr;
  }

  function uints(uint256 e0, uint256 e1) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](2);
    arr[0] = e0;
    arr[1] = e1;
    return arr;
  }

  function uints(uint256 e0, uint256 e1, uint256 e2) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](3);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    return arr;
  }

  function uints(uint256 e0, uint256 e1, uint256 e2, uint256 e3) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](4);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    return arr;
  }

  function uints(
    uint256 e0,
    uint256 e1,
    uint256 e2,
    uint256 e3,
    uint256 e4
  ) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](5);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    arr[4] = e4;
    return arr;
  }

  function uints(
    uint256 e0,
    uint256 e1,
    uint256 e2,
    uint256 e3,
    uint256 e4,
    uint256 e5
  ) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](6);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    arr[4] = e4;
    arr[5] = e5;
    return arr;
  }

  function uints(
    uint256 e0,
    uint256 e1,
    uint256 e2,
    uint256 e3,
    uint256 e4,
    uint256 e5,
    uint256 e6
  ) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](7);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    arr[4] = e4;
    arr[5] = e5;
    arr[6] = e6;
    return arr;
  }

  function uints(
    uint256 e0,
    uint256 e1,
    uint256 e2,
    uint256 e3,
    uint256 e4,
    uint256 e5,
    uint256 e6,
    uint256 e7
  ) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](8);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    arr[4] = e4;
    arr[5] = e5;
    arr[6] = e6;
    arr[7] = e7;
    return arr;
  }

  function addresses(address e0) internal pure returns (address[] memory arr) {
    arr = new address[](1);
    arr[0] = e0;
    return arr;
  }

  function addresses(address e0, address e1) internal pure returns (address[] memory arr) {
    arr = new address[](2);
    arr[0] = e0;
    arr[1] = e1;
    return arr;
  }

  function addresses(address e0, address e1, address e2) internal pure returns (address[] memory arr) {
    arr = new address[](3);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    return arr;
  }

  function addresses(address e0, address e1, address e2, address e3) internal pure returns (address[] memory arr) {
    arr = new address[](4);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    return arr;
  }

  function addresses(
    address e0,
    address e1,
    address e2,
    address e3,
    address e4
  ) internal pure returns (address[] memory arr) {
    arr = new address[](5);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    arr[4] = e4;
    return arr;
  }

  function addresses(
    address e0,
    address e1,
    address e2,
    address e3,
    address e4,
    address e5
  ) internal pure returns (address[] memory arr) {
    arr = new address[](6);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    arr[4] = e4;
    arr[5] = e5;
    return arr;
  }

  function addresses(
    address e0,
    address e1,
    address e2,
    address e3,
    address e4,
    address e5,
    address e6
  ) internal pure returns (address[] memory arr) {
    arr = new address[](7);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    arr[4] = e4;
    arr[5] = e5;
    arr[6] = e6;
    return arr;
  }

  function addresses(
    address e0,
    address e1,
    address e2,
    address e3,
    address e4,
    address e5,
    address e6,
    address e7
  ) internal pure returns (address[] memory arr) {
    arr = new address[](8);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    arr[4] = e4;
    arr[5] = e5;
    arr[6] = e6;
    arr[7] = e7;
    return arr;
  }

  function bytes4s(bytes4 e0, bytes4 e1, bytes4 e2) internal pure returns (bytes4[] memory arr) {
    arr = new bytes4[](3);
    arr[0] = bytes4(e0);
    arr[1] = bytes4(e1);
    arr[2] = bytes4(e2);
    return arr;
  }

  function bytes4s(bytes4 e0, bytes4 e1, bytes4 e2, bytes4 e3) internal pure returns (bytes4[] memory arr) {
    arr = new bytes4[](4);
    arr[0] = bytes4(e0);
    arr[1] = bytes4(e1);
    arr[2] = bytes4(e2);
    arr[3] = bytes4(e3);
    return arr;
  }

  function bytes4s(bytes4 e0, bytes4 e1, bytes4 e2, bytes4 e3, bytes4 e4) internal pure returns (bytes4[] memory arr) {
    arr = new bytes4[](5);
    arr[0] = bytes4(e0);
    arr[1] = bytes4(e1);
    arr[2] = bytes4(e2);
    arr[3] = bytes4(e3);
    arr[4] = bytes4(e4);
    return arr;
  }

  function bytes32s(bytes32 e0) internal pure returns (bytes32[] memory arr) {
    arr = new bytes32[](1);
    arr[0] = e0;
    return arr;
  }

  function bytes32s(bytes32 e0, bytes32 e1) internal pure returns (bytes32[] memory arr) {
    arr = new bytes32[](2);
    arr[0] = e0;
    arr[1] = e1;
    return arr;
  }

  function bytes32s(bytes32 e0, bytes32 e1, bytes32 e2) internal pure returns (bytes32[] memory arr) {
    arr = new bytes32[](3);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    return arr;
  }

  function bytes32s(bytes32 e0, bytes32 e1, bytes32 e2, bytes32 e3) internal pure returns (bytes32[] memory arr) {
    arr = new bytes32[](4);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    return arr;
  }

  function bytes32s(
    bytes32 e0,
    bytes32 e1,
    bytes32 e2,
    bytes32 e3,
    bytes32 e4
  ) internal pure returns (bytes32[] memory arr) {
    arr = new bytes32[](5);
    arr[0] = e0;
    arr[1] = e1;
    arr[2] = e2;
    arr[3] = e3;
    arr[4] = e4;
    return arr;
  }

  function contains(address[] memory self, address value) internal pure returns (bool) {
    for (uint i = 0; i < self.length; i++) {
      if (self[i] == value) {
        return true;
      }
    }
    return false;
  }

  function merge(address[] memory a, address[] memory b) internal pure returns (address[] memory) {
    address[] memory result = new address[](a.length + b.length);
    for (uint i = 0; i < a.length; i++) {
      result[i] = a[i];
    }
    for (uint i = 0; i < b.length; i++) {
      result[a.length + i] = b[i];
    }
    return result;
  }
}
