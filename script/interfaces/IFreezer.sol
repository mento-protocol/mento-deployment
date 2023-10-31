pragma solidity ^0.5.13;

interface IFreezer {
  function freeze(address target) external;

  function unfreeze(address target) external;

  function isFrozen(address account) external view returns (bool);
}
