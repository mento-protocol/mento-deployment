// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { Ownable } from "openzeppelin-contracts-next/contracts/access/Ownable.sol";

interface ISortedOraclesMin {
  function report(address rateFeedId, uint256 value, address lesserKey, address greaterKey) external;

  function getRates(address rateFeedId) external returns (address[] memory, uint256[] memory, uint256[] memory);

  function removeExpiredReports(address rateFeedId, uint256 n) external;
}

contract MockRedstoneAdapter is Ownable {
  address public sortedOracles;
  address public externalProvider;

  address[] public mainnetRateFeeds;
  address[] public alfajoresRateFeeds;

  mapping(address => uint256) public lastMainnetPricePerFeed;
  uint128 public lastDataTimestamp;
  uint128 public lastBlockTimestamp;

  modifier onlyOwnerOrExternalProvider() {
    require(
      msg.sender == owner() || msg.sender == externalProvider,
      "Only owner or external provider can call this function"
    );
    _;
  }

  constructor() {}

  function setExternalProvider(address _externalProvider) external onlyOwner {
    externalProvider = _externalProvider;
  }

  function setRateFeeds(address[] memory _mainnetRateFeeds, address[] memory _alfajoresRateFeeds) external onlyOwner {
    mainnetRateFeeds = _mainnetRateFeeds;
    alfajoresRateFeeds = _alfajoresRateFeeds;
  }

  function setSortedOracles(address _sortedOracles) external onlyOwner {
    sortedOracles = _sortedOracles;
  }

  function update(
    address[] memory _mainnetFeeds,
    uint256[] memory _prices,
    uint128 _dataTimestamp,
    uint128 _blockTimestamp
  ) external onlyOwnerOrExternalProvider {
    require(_mainnetFeeds.length == _prices.length, "Mainnet feeds and prices must be the same length");
    require(_mainnetFeeds.length > 0, "Feeds must not be empty");
    for (uint256 i = 0; i < _mainnetFeeds.length; i++) {
      lastMainnetPricePerFeed[_mainnetFeeds[i]] = _prices[i];
    }
    lastDataTimestamp = _dataTimestamp;
    lastBlockTimestamp = _blockTimestamp;
  }

  function relay() external onlyOwnerOrExternalProvider {
    uint256 length = mainnetRateFeeds.length;
    for (uint256 i = 0; i < length; i++) {
      address mainnetRateFeed = mainnetRateFeeds[i];
      address alfajoresRateFeed = alfajoresRateFeeds[i];
      uint256 lastMainnetPrice = lastMainnetPricePerFeed[mainnetRateFeed];
      uint256 scaled = lastMainnetPrice * (10 ** 16); // Redstone uses 8 decimals and sortedOracles expects 24

      reportRate(alfajoresRateFeed, scaled);
    }
  }

  function reportRate(address rateFeedId, uint256 rate) internal {
    // Copied from ChainlinkRelayerV1.reportRate()
    (address[] memory oracles, uint256[] memory rates, ) = ISortedOraclesMin(sortedOracles).getRates(rateFeedId);
    uint256 numRates = oracles.length;

    if (numRates == 0 || (numRates == 1 && oracles[0] == address(this))) {
      // Happy path: SortedOracles is empty, or there is a single report from this relayer.
      ISortedOraclesMin(sortedOracles).report(rateFeedId, rate, address(0), address(0));
      return;
    }

    if (numRates > 2 || (numRates == 2 && oracles[0] != address(this) && oracles[1] != address(this))) {
      require(false, "More than 2 reports from other oracles");
    }

    // At this point we have ensured that either:
    // - There is a single report from another oracle.
    // - There are two reports and one is from this relayer.

    address otherOracle;
    uint256 otherRate;

    if (numRates == 1 || oracles[0] != address(this)) {
      otherOracle = oracles[0];
      otherRate = rates[0];
    } else {
      otherOracle = oracles[1];
      otherRate = rates[1];
    }

    address lesserKey;
    address greaterKey;

    if (otherRate < rate) {
      lesserKey = otherOracle;
    } else {
      greaterKey = otherOracle;
    }

    ISortedOraclesMin(sortedOracles).report(rateFeedId, rate, lesserKey, greaterKey);
    ISortedOraclesMin(sortedOracles).removeExpiredReports(rateFeedId, 1);
  }

  function getMainnetRateFeeds() external view returns (address[] memory) {
    return mainnetRateFeeds;
  }

  function getAlfajoresRateFeeds() external view returns (address[] memory) {
    return alfajoresRateFeeds;
  }
}
