// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { Broker } from "mento-core-2.6.0/swap/Broker.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IReserve } from "mento-core-2.6.0/interfaces/IReserve.sol";
import { IGoodDollarExchangeProvider } from "mento-core-2.6.0/interfaces/IGoodDollarExchangeProvider.sol";
import { IGoodDollarExpansionController } from "mento-core-2.6.0/interfaces/IGoodDollarExpansionController.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";
import { IBrokerAdmin } from "mento-core-2.6.0/interfaces/IBrokerAdmin.sol";
import { ITradingLimits } from "mento-core-2.6.0/interfaces/ITradingLimits.sol";
import { IERC20Lite } from "script/interfaces/IERC20Lite.sol";

interface IProxyAdminLite {
  function getProxyAdmin(address proxy) external view returns (address);

  function changeProxyAdmin(address proxy, address newAdmin) external;
}

interface IProxyLite {
  function _getImplementation() external view returns (address);

  function _getOwner() external view returns (address);

  function _transferOwnership(address) external;

  function _setImplementation(address newImplementation) external;

  function _setAndInitializeImplementation(address implementation, bytes calldata callbackData) external;
}

interface ITransparentUpgradeableProxyLite {
  function admin() external view returns (address);

  function implementation() external view returns (address);

  function changeAdmin(address) external;

  function upgradeTo(address) external;

  function upgradeToAndCall(address, bytes memory) external payable;
}

contract GD is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;

  ICeloGovernance.Transaction[] private transactions;

  address private goodDollarExchangeProviderProxy;
  address private goodDollarExpansionControllerProxy;
  address private goodDollarReserveProxy;
  address private mentoReserveProxy;
  address private brokerProxy;
  address private biPoolManagerProxy;
  address private cUSDProxy;

  address private goodDollarExchangeProviderImplementation;
  address private goodDollarExpansionControllerImplementation;
  address private newBrokerImplementation;
  address private reserveImplementation;

  address private goodDollarAvatar;
  address private goodDollarDistributionHelper;
  address private celoRegistry;
  address private goodDollarToken;
  address private governanceFactory;

  function loadDeployedContracts() internal {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest"); // BrokerProxy
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest"); // GovernanceFactory
    contracts.loadSilent("GD-00-Deploy-Implementations", "latest"); // new GD Implementations
    contracts.loadSilent("GD-01-Deploy-Proxies", "latest"); // new GD Proxies
  }

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  function setAddresses() internal {
    // TODO: fix GoodDollar proxies are deployed without the name
    goodDollarExchangeProviderProxy = contracts.deployed("GoodDollarExchangeProviderProxy");
    //goodDollarExchangeProviderProxy = 0xa82C990D587FfADe7ab91B436269EA0C39a39929;
    goodDollarExpansionControllerProxy = contracts.deployed("GoodDollarExpansionControllerProxy");
    //goodDollarExpansionControllerProxy = 0xF70455bb461724f133794C3BbABad573D8c098a4;
    goodDollarReserveProxy = contracts.deployed("GoodDollarReserveProxy");
    mentoReserveProxy = contracts.celoRegistry("Reserve");
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    cUSDProxy = contracts.celoRegistry("StableToken");

    goodDollarExchangeProviderImplementation = contracts.deployed("GoodDollarExchangeProvider");
    goodDollarExpansionControllerImplementation = contracts.deployed("GoodDollarExpansionController");
    newBrokerImplementation = contracts.deployed("Broker");
    reserveImplementation = IProxyLite(mentoReserveProxy)._getImplementation();

    // TODO: hardcode addresses from G$
    goodDollarAvatar = 0x56fD3F2bEE130e9867942D0F463a16fBE49B8d81;
    goodDollarDistributionHelper = 0x56fD3F2bEE130e9867942D0F463a16fBE49B8d81;

    celoRegistry = 0x000000000000000000000000000000000000ce10;
    goodDollarToken = 0x62B8B11039FcfE5aB0C56E502b1C372A3d2a9c7A;
    governanceFactory = contracts.deployed("GovernanceFactory");
  }

  function run() public {
    prepare();

    address governance = IGovernanceFactory(governanceFactory).mentoGovernor();
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "TODO", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    //proposal_upgradeBrokerImplementation();
    proposal_initializeGDReserve();
    //proposal_configureGDReserve();
    //proposal_initializeGDExchangeProvider();
    //proposal_initializeGDExpansionController();
    //proposal_configureNewBroker();
    //proposal_configureGDTradingLimits();

    return transactions;
  }

  function proposal_upgradeBrokerImplementation() public {
    address currentBrokerImplementation = IProxyLite(brokerProxy)._getImplementation();
    if (currentBrokerImplementation != newBrokerImplementation) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          brokerProxy,
          abi.encodeWithSelector(IProxyLite._setImplementation.selector, newBrokerImplementation)
        )
      );
    }
  }

  function proposal_initializeGDReserve() public {
    
    // TODO verify this configuration is correct
    //if (IProxyLite(goodDollarReserveProxy)._getImplementation() == address(0)) {
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        goodDollarReserveProxy,
        abi.encodeWithSelector(
          IReserve.initialize.selector,
          celoRegistry,
          3153600000, // _tobinTaxStalenessThreshold: 100 years non relevant copied from main reserve config
          1e24, // 1e24 = 100% CELO spending
          0, // no frozen gold
          0, // no frozen days
          Arrays.bytes32s("cUSD", "cGLD"), // Celo needs to be added
          Arrays.uints(1e24 - 1, 1), // 1e24 - 1 = 99.999999999999999999999999% weight for cUSD, 1 for cGLD because it's not used
          0, // disabled tobin tax
          0, // disabled tobin tax reserve ratio
          Arrays.addresses(cUSDProxy), // cUSD only collateral asset
          Arrays.uints(1e24) // 1e24 = 100% daily spending ratio
        )
      )
    );
    //}
  }

  function proposal_configureGDReserve() public {
    // add G$ as stable asset to GD Reserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        goodDollarReserveProxy,
        abi.encodeWithSelector(IReserve(goodDollarReserveProxy).addToken.selector, goodDollarToken)
      )
    );

    // add Broker as exchange Spender on GD Reserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        goodDollarReserveProxy,
        abi.encodeWithSelector(IReserve.addExchangeSpender.selector, brokerProxy)
      )
    );

    // TODO how to configure the GD Reserve:
    // - set the avatar as reserve Spender?
    // - set Mento Reserve as other Reserve?
    // - set MentoLabsMultisig as Reserve spender?
  }

  function proposal_initializeGDExchangeProvider() public {
    // initialize the Good Dollar Exchange Provider
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        goodDollarExchangeProviderProxy,
        abi.encodeWithSelector(
          IGoodDollarExchangeProvider.initialize.selector,
          brokerProxy,
          goodDollarReserveProxy,
          goodDollarExpansionControllerProxy,
          goodDollarAvatar
        )
      )
    );
  }

  function proposal_initializeGDExpansionController() public {
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        goodDollarExpansionControllerProxy,
        abi.encodeWithSelector(
          IGoodDollarExpansionController.initialize.selector,
          goodDollarExchangeProviderProxy,
          goodDollarDistributionHelper,
          goodDollarReserveProxy,
          goodDollarAvatar
        )
      )
    );
  }

  function proposal_configureNewBroker() public {
    // add GoodDollarExchangeProvider as ExchangeProvider to Broker
    if (!Broker(brokerProxy).isExchangeProvider(goodDollarExchangeProviderProxy)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          brokerProxy,
          abi.encodeWithSelector(
            IBrokerAdmin.addExchangeProvider.selector,
            goodDollarExchangeProviderProxy,
            goodDollarReserveProxy
          )
        )
      );
    }

    // configure IExchangeProvider -> IReserve mapping for BiPoolManager and MentoReserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxy,
        abi.encodeWithSelector(
          IBrokerAdmin.setReserves.selector,
          Arrays.addresses(biPoolManagerProxy),
          Arrays.addresses(mentoReserveProxy)
        )
      )
    );
  }

  function proposal_configureGDTradingLimits() public {
    // TODO verify tradinglimit params

    // TODO: need mock G$ on alfajores in order for the symbol call to work
    bytes32 exchangeID = keccak256(abi.encodePacked(IERC20Lite(cUSDProxy).symbol(), IERC20Lite(cUSDProxy).symbol()));

    ITradingLimits.Config memory config = ITradingLimits.Config({
      timestep0: 300, // 5 minutes
      timestep1: 86400, // 1 days
      limit0: 5_000, // 5k cUSD
      limit1: 50_000, // 50k cUSD
      limitGlobal: 100_000, // 100k cUSD
      flags: uint8(1 | 2 | 4) // L0, L1, LG
    });

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        brokerProxy,
        abi.encodeWithSelector(Broker.configureTradingLimit.selector, exchangeID, cUSDProxy, config)
      )
    );
  }
}
