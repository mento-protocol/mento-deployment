pragma solidity 0.8.18;

import { Script } from "script/utils/mento/Script.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { console2 } from "forge-std/Script.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IGoodDollarExchangeProvider } from "mento-core-2.6.0/interfaces/IGoodDollarExchangeProvider.sol";
import { IGoodDollarExpansionController } from "mento-core-2.6.0/interfaces/IGoodDollarExpansionController.sol";
import { TransparentUpgradeableProxy } from "mento-core-2.6.0/../lib/openzeppelin-contracts-next/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

interface IOwnableLite {
  function transferOwnership(address newOwner) external;
}

interface IProxyLite {
  function _getImplementation() external view returns (address);
}

contract GD_00_Deploy_Proxies is Script {
  using Contracts for Contracts.Cache;

  address public goodDollarReserveProxy;
  address public goodDollarExchangeProviderProxy;
  address public goodDollarExpansionControllerProxy;

  address public reserveImplementation;
  address public goodDollarExchangeProviderImplementation;
  address public goodDollarExpansionControllerImplementation;

  address public governanceFactory;
  address public timelockProxy;
  address public proxyAdmin;

  address public brokerProxy;
  address public mentoReserveProxy;
  address public AVATAR;
  address public distributionHelper;

  function run() public {
    contracts.load("MU01-00-Create-Proxies", "latest"); // BrokerProxy
    contracts.loadSilent("GD-00-Deploy-Implementations", "latest"); // GD Implementations
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest"); // GovernanceFactory

    governanceFactory = contracts.deployed("GovernanceFactory");
    require(governanceFactory != address(0), "GovernanceFactory not found");

    proxyAdmin = IGovernanceFactory(governanceFactory).proxyAdmin();
    require(proxyAdmin != address(0), "ProxyAdmin not found");

    timelockProxy = IGovernanceFactory(governanceFactory).governanceTimelock();
    require(timelockProxy != address(0), "TimelockProxy not found");

    mentoReserveProxy = contracts.celoRegistry("Reserve");
    reserveImplementation = IProxyLite(mentoReserveProxy)._getImplementation();
    require(reserveImplementation != address(0), "Reserve implementation not found");

    goodDollarExchangeProviderImplementation = contracts.deployed("GoodDollarExchangeProvider");
    require(goodDollarExchangeProviderImplementation != address(0), "GoodDollarExchangeProvider not found");

    goodDollarExpansionControllerImplementation = contracts.deployed("GoodDollarExpansionController");
    require(goodDollarExpansionControllerImplementation != address(0), "GoodDollarExpansionController not found");

    brokerProxy = contracts.deployed("BrokerProxy");
    require(brokerProxy != address(0), "BrokerProxy not found");

    AVATAR = 0x56fD3F2bEE130e9867942D0F463a16fBE49B8d81;
    distributionHelper = 0x56fD3F2bEE130e9867942D0F463a16fBE49B8d81;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      goodDollarReserveProxy = payable(address(new TransparentUpgradeableProxy(reserveImplementation, proxyAdmin, "")));

      goodDollarExchangeProviderProxy = payable(
        address(new TransparentUpgradeableProxy(goodDollarExchangeProviderImplementation, proxyAdmin, ""))
      );

      goodDollarExpansionControllerProxy = payable(
        address(new TransparentUpgradeableProxy(goodDollarExpansionControllerImplementation, proxyAdmin, ""))
      );

      IGoodDollarExchangeProvider(goodDollarExchangeProviderProxy).initialize(
        brokerProxy,
        goodDollarReserveProxy,
        goodDollarExpansionControllerProxy,
        AVATAR
      );

      IGoodDollarExpansionController(goodDollarExpansionControllerProxy).initialize(
        goodDollarExchangeProviderProxy,
        distributionHelper,
        goodDollarReserveProxy,
        AVATAR
      );

      IOwnableLite(goodDollarExchangeProviderProxy).transferOwnership(timelockProxy);
      IOwnableLite(goodDollarExpansionControllerProxy).transferOwnership(timelockProxy);
      IOwnableLite(goodDollarReserveProxy).transferOwnership(timelockProxy);
    }
    vm.stopBroadcast();
  }
}
