// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { ERC20 } from "2.0.0/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { ERC20Detailed } from "2.0.0/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20Detailed.sol";
import { Ownable } from "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract MockERC20 is ERC20, ERC20Detailed, Ownable {
  constructor(
    string memory name,
    string memory symbol,
    uint8 decimals
  ) public ERC20Detailed(name, symbol, decimals) {
    mint(msg.sender, 100_000_000 ether);
  }

  function mint(address to, uint256 amount) public onlyOwner returns (bool) {
    _mint(to, amount);
    return true;
  }
}
