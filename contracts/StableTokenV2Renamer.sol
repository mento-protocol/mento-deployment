// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { TempStable } from "mento-core-2.6.4/tokens/TempStable.sol";

/**
 * @title Temporary implementation for StableTokenV2.
 * @dev Has a Symbol update function and Symbol variable in the same slot as the original
 *      implementation.
 */
contract StableTokenV2Renamer is TempStable {
  string private _symbol; // slot 3

  function setSymbol(string calldata newSymbol) external onlyOwner {
    _symbol = newSymbol;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }
}
