// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable var-name-mixedcase, const-name-snakecase
pragma solidity ^0.8.18;

import { console2 as console } from "forge-std/Script.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

interface IAggregatorV3 {
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function description() external view returns (string memory);
}

interface IMockAggregator {
  function setAnswer(int256 answer) external;

  function description() external view returns (string memory);
}

/**
 * Usage: yarn script:dev -n alfajores -s UpdateMockChainlinkAggregators
 * Chainlink doesn't report all rates on testnets so in order to have as close
 * of a setup as possible between environments we deploy MockAggregatorV3
 * instances for the data feeds that are missing on Alfajores.
 * This script pulls data from the mainnet aggregators and updates the
 * mocks on Alfajores, and can be run periodically during testing.
 */
contract UpdateMockChainlinkAggregators is Script {
  using Contracts for Contracts.Cache;
  address private constant PHPUSDMainnetAggregator = 0x4ce8e628Bb82Ea5271908816a6C580A71233a66c;
  address private constant CELOUSDMainnetAggregator = 0x0568fD19986748cEfF3301e55c0eb1E729E0Ab7e;
  address private constant COPUSDMainnetAggregator = 0x97b770B0200CCe161907a9cbe0C6B177679f8F7C;
  address private constant GHSUSDMainnetAggregator = 0x2719B648DB57C5601Bd4cB2ea934Dec6F4262cD8;
  address private constant ETHUSDMainnetAggregator = 0x1FcD30A73D67639c1cD89ff5746E7585731c083B;
  address private constant CHFUSDMainnetAggregator = 0xfd49bFcb3dc4aAa713c25e7d23B14BB39C4B8857;
  address private constant GBPUSDMainnetAggregator = 0xe76FE54dfeD2ce8B4d1AC63c982DfF7CFc92bf82;
  address private constant ZARUSDMainnetAggregator = 0x11b7221a0DD025778A95e9E0B87b477522C32E02;
  address private constant CADUSDMainnetAggregator = 0x2f6d6cB9e01d63e1a1873BACc5BfD4e7d4e461d1;
  address private constant AUDUSDMainnetAggregator = 0xf2Bd4FAa89f5A360cDf118bccD183307fDBcB6F5;
  address private constant XOFUSDMainnetAggregator = 0x1626095f9548291cA67A6Aa743c30A1BB9380c9d;
  address private constant EURCUSDMainnetAggregator = 0x9a48d9b0AF457eF040281A9Af3867bc65522Fecd;
  address private constant USDCUSDMainnetAggregator = 0xc7A353BaE210aed958a1A2928b654938EC59DaB2;
  address private constant USDTUSDMainnetAggregator = 0x5e37AF40A7A344ec9b03CCD34a250F3dA9a20B02;

  mapping(address => address) private mockForAggregator;
  mapping(address => int256) private aggregatorAnswers;
  mapping(address => string) private aggregatorDescription;
  address[] private aggregatorsToForward;

  constructor() Script() {
    if (ChainLib.isAlfajores()) {
      setUp_alfajores();
    } else {
      console.log("This script is only meant to be run on testnets");
    }
  }

  function setUp_alfajores() internal {
    /// @dev Load additional deployed aggregators here to forward rates
    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "PHPUSD");
    address PHPUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "COPUSD");
    address COPUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "GHSUSD");
    address GHSUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "ETHUSD");
    address ETHUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "CHFUSD");
    address CHFUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "GBPUSD");
    address GBPUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "ZARUSD");
    address ZARUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "CADUSD");
    address CADUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "AUDUSD");
    address AUDUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "XOFUSD");
    address XOFUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "EURCUSD");
    address EURCUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "USDCUSD");
    address USDCUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "USDTUSD");
    address USDTUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    mockForAggregator[PHPUSDMainnetAggregator] = PHPUSDTestnetMock;
    mockForAggregator[COPUSDMainnetAggregator] = COPUSDTestnetMock;
    mockForAggregator[GHSUSDMainnetAggregator] = GHSUSDTestnetMock;
    mockForAggregator[ETHUSDMainnetAggregator] = ETHUSDTestnetMock;
    mockForAggregator[CHFUSDMainnetAggregator] = CHFUSDTestnetMock;
    mockForAggregator[GBPUSDMainnetAggregator] = GBPUSDTestnetMock;
    mockForAggregator[ZARUSDMainnetAggregator] = ZARUSDTestnetMock;
    mockForAggregator[CADUSDMainnetAggregator] = CADUSDTestnetMock;
    mockForAggregator[AUDUSDMainnetAggregator] = AUDUSDTestnetMock;
    mockForAggregator[XOFUSDMainnetAggregator] = XOFUSDTestnetMock;
    mockForAggregator[EURCUSDMainnetAggregator] = EURCUSDTestnetMock;
    mockForAggregator[USDCUSDMainnetAggregator] = USDCUSDTestnetMock;
    mockForAggregator[USDTUSDMainnetAggregator] = USDTUSDTestnetMock;

    aggregatorsToForward.push(PHPUSDMainnetAggregator);
    aggregatorsToForward.push(COPUSDMainnetAggregator);
    aggregatorsToForward.push(GHSUSDMainnetAggregator);
    aggregatorsToForward.push(ETHUSDMainnetAggregator);
    aggregatorsToForward.push(CHFUSDMainnetAggregator);
    aggregatorsToForward.push(GBPUSDMainnetAggregator);
    aggregatorsToForward.push(ZARUSDMainnetAggregator);
    aggregatorsToForward.push(CADUSDMainnetAggregator);
    aggregatorsToForward.push(AUDUSDMainnetAggregator);
    aggregatorsToForward.push(XOFUSDMainnetAggregator);
    aggregatorsToForward.push(EURCUSDMainnetAggregator);
    aggregatorsToForward.push(USDCUSDMainnetAggregator);
    aggregatorsToForward.push(USDTUSDMainnetAggregator);
  }

  function run() public {
    uint256 celoFork = vm.createFork("celo");
    uint256 testnetFork = vm.createFork(ChainLib.rpcToken());

    vm.selectFork(celoFork);
    for (uint i = 0; i < aggregatorsToForward.length; i++) {
      address agg = aggregatorsToForward[i];
      (, int256 answer, , , ) = IAggregatorV3(agg).latestRoundData();
      aggregatorAnswers[agg] = answer;
      aggregatorDescription[agg] = IAggregatorV3(agg).description();
    }

    vm.selectFork(testnetFork);

    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      for (uint i = 0; i < aggregatorsToForward.length; i++) {
        address agg = aggregatorsToForward[i];
        address mock = mockForAggregator[agg];
        int256 answer = aggregatorAnswers[agg];
        IMockAggregator(mock).setAnswer(answer);
        console.log("Update %s mock aggregator with value: %d", IMockAggregator(mock).description(), uint256(answer));
        console.log("       From mainnet aggregator: %s (%s)", aggregatorDescription[agg], address(agg));
        console.log("       Testnet mock aggregator: %s", mock);
        console.log("\n");
      }
    }
    vm.stopBroadcast();
  }
}
