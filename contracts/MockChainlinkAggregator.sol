// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { Ownable } from "openzeppelin-contracts-next/contracts/access/Ownable.sol";

contract MockChainlinkAggregator is Ownable {
  string public description;
  uint8 public decimals;
  int256 public savedAnswer;
  uint256 public lastUpdated;

  // An external address that can set the answer and lastUpdated of the aggregator
  // Used to run an off-chain script that fetches mainnet chainlink data and relays it to Alfajores
  address public externalProvider;

  modifier onlyOwnerOrExternalProvider() {
    require(
      msg.sender == owner() || msg.sender == externalProvider,
      "Only owner or external provider can call this function"
    );
    _;
  }

  constructor(string memory _description, uint8 _decimals) {
    description = _description;
    decimals = _decimals;
  }

  function setExternalProvider(address _externalProvider) external onlyOwner {
    externalProvider = _externalProvider;
  }

  function setDecimals(uint8 _decimals) external onlyOwner {
    decimals = _decimals;
  }

  function setAnswer(int256 _answer) external onlyOwnerOrExternalProvider {
    savedAnswer = _answer;
  }

  function setLastUpdated(uint256 _lastUpdated) external onlyOwnerOrExternalProvider {
    lastUpdated = _lastUpdated;
  }

  function report(int256 _answer, uint256 _lastUpdated) external onlyOwnerOrExternalProvider {
    savedAnswer = _answer;
    lastUpdated = _lastUpdated;
  }

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (uint80(0), savedAnswer, uint256(0), lastUpdated, uint80(0));
  }
}
