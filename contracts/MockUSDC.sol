pragma solidity ^0.5.13;

import { ERC20 } from "lib/mento-core/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { ERC20Detailed } from "lib/mento-core/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20Detailed.sol";
import { Ownable } from "lib/mento-core/lib/openzeppelin-contracts/contracts/ownership/Ownable.sol";


contract MockUSDC is ERC20, ERC20Detailed, Ownable {

  constructor() public ERC20Detailed("mockUSDC", "USDC", 18) {
    mint(msg.sender, 1000000 ether);
  }

  function mint(address to, uint256 amount) public onlyOwner returns (bool){
    _mint(to, amount);
    return true;
  }
}
