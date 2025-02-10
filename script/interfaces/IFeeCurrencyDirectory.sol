pragma solidity ^0.5.13;

interface IFeeCurrencyDirectory {
  function setCurrencyConfig(address token, address oracle, uint256 intrinsicGas) external;

  function getCurrencies() external view returns (address[] memory);
}
