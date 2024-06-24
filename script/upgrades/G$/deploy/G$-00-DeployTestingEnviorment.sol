// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Reserve } from "mento-core-3.0.0/swap/Reserve.sol";
import { FixidityLib } from "../../../utils/FixidityLib.sol";
import { IStableTokenV2 } from "mento-core-3.0.0/interfaces/IStableTokenV2.sol";
import { IBroker } from "mento-core-3.0.0/interfaces/IBroker.sol";

contract GoodDollar_CreateTestingEnviorment is Script {
  function run() public {
    address mockGoodDollarExchangeProvider;
    string memory gdProviderPath = string(
      abi.encodePacked("out/GoodDollarExchangeProvider.sol/GoodDollarExchangeProvider.json")
    );
    bytes memory gdProviderBytecode = abi.encodePacked(vm.getCode(gdProviderPath), abi.encode(false));

    address mockGoodDollarExpansionController;
    string memory gdExpansionControllerPath = string(
      abi.encodePacked("out/GoodDollarExpansionController.sol/GoodDollarExpansionController.json")
    );
    bytes memory gdExpansionControllerBytecode = abi.encodePacked(
      vm.getCode(gdExpansionControllerPath),
      abi.encode(false)
    );

    address mockCUSD;
    string memory cusdPath = string(abi.encodePacked("out/StableTokenV2.sol/StableTokenV2.json"));
    bytes memory cusdBytecode = abi.encodePacked(vm.getCode(cusdPath), abi.encode(false));

    address mockBrokerV2;
    string memory brokerPath = string(abi.encodePacked("out/Broker.sol/Broker.json"));
    bytes memory brokerBytecode = abi.encodePacked(vm.getCode(brokerPath), abi.encode(true));

    address payable mockReserve;

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      assembly {
        mockGoodDollarExchangeProvider := create(0, add(gdProviderBytecode, 0x20), mload(gdProviderBytecode))

        mockGoodDollarExpansionController := create(
          0,
          add(gdExpansionControllerBytecode, 0x20),
          mload(gdExpansionControllerBytecode)
        )

        mockCUSD := create(0, add(cusdBytecode, 0x20), mload(cusdBytecode))

        mockBrokerV2 := create(0, add(brokerBytecode, 0x20), mload(brokerBytecode))
      }

      // configure and initilize mockReserve

      mockReserve = address(new Reserve(true));

      configureReserve(address(uint160(mockReserve)), mockBrokerV2, mockCUSD);

      // configure and initialize mockCUSD
      address[] memory initialBalanceAddresses = new address[](0);
      uint256[] memory initialBalances = new uint256[](0);
      IStableTokenV2(mockCUSD).initialize(
        "mockCUSD",
        "mockCUSD",
        0,
        address(0),
        0,
        0,
        initialBalanceAddresses,
        initialBalances,
        ""
      );
      IStableTokenV2(mockCUSD).initializeV2(address(mockBrokerV2), address(0), address(0));

      // // configure and initialize mockBrokerV2

      configureBrokerV2(mockBrokerV2, mockGoodDollarExchangeProvider, mockReserve);
    }
    vm.stopBroadcast();

    console.log("----------");
    console.log("----------");
  }

  function configureReserve(address payable reserve, address broker, address collateralAsset) public {
    bytes32[] memory initialAssetAllocationSymbols = new bytes32[](2);
    initialAssetAllocationSymbols[0] = bytes32("cGLD");
    initialAssetAllocationSymbols[1] = bytes32("mockCUSD");
    uint256[] memory initialAssetAllocationWeights = new uint256[](2);
    initialAssetAllocationWeights[0] = FixidityLib.newFixedFraction(1, 2).unwrap();
    initialAssetAllocationWeights[1] = FixidityLib.newFixedFraction(1, 2).unwrap();
    uint256 tobinTax = FixidityLib.newFixedFraction(5, 1000).unwrap();
    uint256 tobinTaxReserveRatio = FixidityLib.newFixedFraction(2, 1).unwrap();
    address[] memory collateralAssets = new address[](1);
    collateralAssets[0] = collateralAsset;

    uint256[] memory collateralAssetDailySpendingRatios = new uint256[](1);
    collateralAssetDailySpendingRatios[0] = 1e24;
    Reserve(reserve).initialize(
      0x000000000000000000000000000000000000ce10,
      600, // deprecated
      1000000000000000000000000,
      0,
      0,
      initialAssetAllocationSymbols,
      initialAssetAllocationWeights,
      tobinTax,
      tobinTaxReserveRatio,
      collateralAssets,
      collateralAssetDailySpendingRatios
    );
    Reserve(reserve).addToken(0x62B8B11039FcfE5aB0C56E502b1C372A3d2a9c7A);
    Reserve(reserve).addExchangeSpender(broker);
  }

  function configureBrokerV2(address brokerV2, address exchangeProvider, address reserve) public {
    address[] memory exchangeProviders = new address[](1);
    address[] memory reserves = new address[](1);
    exchangeProviders[0] = exchangeProvider;
    reserves[0] = reserve;
    IBroker(brokerV2).initialize(exchangeProviders, reserves);
  }
}
