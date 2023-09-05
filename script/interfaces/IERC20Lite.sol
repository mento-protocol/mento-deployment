// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

interface IERC20Lite {
  /**
   * @dev Returns the symbol of the token.
   */
  function symbol() external view returns (string memory);
}
