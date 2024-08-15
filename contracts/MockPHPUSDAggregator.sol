// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

contract MockPHPUSDAggregator {
  int256 public savedAnswer;

  constructor() {}

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function setAnswer(int256 _answer) external {
    savedAnswer = _answer;
  }

  // Always look like the answer is revent to avoid timestamp spread issues
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (uint80(0), savedAnswer, uint256(0), block.timestamp, uint80(0));
  }
}
