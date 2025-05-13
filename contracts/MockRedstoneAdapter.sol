// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { Ownable } from "openzeppelin-contracts-next/contracts/access/Ownable.sol";

interface ISortedOraclesMin {
  function report(address rateFeedId, uint256 value, address lesserKey, address greaterKey) external;
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
    for (uint256 i = 0; i < _mainnetFeeds.length; i++) {
      lastMainnetPricePerFeed[_mainnetFeeds[i]] = _prices[i];
    }
    lastDataTimestamp = _dataTimestamp;
    lastBlockTimestamp = _blockTimestamp;
  }

  function relay() external onlyOwnerOrExternalProvider {
    ISortedOraclesMin _sortedOracles = ISortedOraclesMin(sortedOracles);
    for (uint256 i = 0; i < mainnetRateFeeds.length; i++) {
      address mainnetRateFeed = mainnetRateFeeds[i];
      address alfajoresRateFeed = alfajoresRateFeeds[i];
      uint256 lastMainnetPrice = lastMainnetPricePerFeed[mainnetRateFeed];
      uint256 scaled = lastMainnetPrice * (10 ** 16); // Redstone uses 8 decimals and sortedOracles expects 24

      // Assume there is only one report per feed
      ISortedOraclesMin(sortedOracles).report(alfajoresRateFeed, scaled, address(0), address(0));
    }
  }

  function getMainnetRateFeeds() external view returns (address[] memory) {
    return mainnetRateFeeds;
  }

  function getAlfajoresRateFeeds() external view returns (address[] memory) {
    return alfajoresRateFeeds;
  }
}
