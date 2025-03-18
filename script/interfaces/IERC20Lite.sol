// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.17 <0.9.0;

interface IERC20Lite {
  /**
   * @dev Returns the symbol of the token.
   */
  function symbol() external view returns (string memory);

  /**
   * @dev Returns the name of the token.
   */
  function name() external view returns (string memory);
}
