pragma solidity ^0.5.13;

import { ERC20 } from "lib/mento-core/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { ERC20Detailed } from "lib/mento-core/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20Detailed.sol";
import { Ownable } from "lib/mento-core/lib/openzeppelin-contracts/contracts/ownership/Ownable.sol";


contract MockERC20 is ERC20, ERC20Detailed, Ownable {

  constructor(string memory name, string memory symbol, uint8 decimals) ERC20Detailed(name, symbol, decimals) public {
    mint(msg.sender, 1000000 ether);
  }

  function mint(address to, uint256 amount) public onlyOwner returns (bool){
    _mint(to, amount);
    return true;
  }
}
