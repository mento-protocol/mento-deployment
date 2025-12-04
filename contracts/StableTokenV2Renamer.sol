// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import { Ownable } from "openzeppelin-contracts-next/contracts/access/Ownable.sol";

/**
 * @title StableTokenV2Renamer
 * @dev Allows the owner to update the name and symbol of a StableTokenV2.
 */
contract StableTokenV2Renamer is Ownable {
  // slot 0 = Ownable._owner
  address public slot1; // slot 1
  string private _name; // slot 2
  string private _symbol; // slot 3

  function setSymbol(string calldata newSymbol) external onlyOwner {
    _symbol = newSymbol;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function setName(string calldata newName) external onlyOwner {
    _name = newName;
  }

  function name() public view returns (string memory) {
    return _name;
  }
}
