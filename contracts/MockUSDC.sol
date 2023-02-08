pragma solidity ^0.5.13;

import { ERC20 } from "lib/mento-core/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { ERC20Detailed } from "lib/mento-core/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20Detailed.sol";

contract MockUSDC is ERC20, ERC20Detailed {
  address public owner;

  modifier onlyOwner() {
    require(msg.sender == owner, "only owner");
    _;
  }

  constructor() public ERC20Detailed("mockUSDC", "USDC", 18) {
    owner = msg.sender;
    mint(owner, 1000000 ether);
  }

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }
}
