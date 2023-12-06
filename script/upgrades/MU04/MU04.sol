// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";

import { IProxy } from "mento-core-2.2.0/common/interfaces/IProxy.sol";
import { IReserve } from "mento-core-2.2.0/interfaces/IReserve.sol";
import { IRegistry } from "mento-core-2.2.0/common/interfaces/IRegistry.sol";
import { IERC20Metadata } from "mento-core-2.2.0/common/interfaces/IERC20Metadata.sol";
import { IStableTokenV2 } from "mento-core-2.2.0/interfaces/IStableTokenV2.sol";
import { IFreezer } from "../../interfaces/IFreezer.sol";

import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { Reserve } from "mento-core-2.2.0/swap/Reserve.sol";
import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";

import { MU04Config, Config } from "./Config.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

contract MU04 is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  ICeloGovernance.Transaction[] private transactions;

  //tokens
  address public stableTokenV2;
  address payable public cUSDProxy;
  address payable public cEURProxy;
  address payable public cBRLProxy;
  address payable public eXOFProxy;
  address public celo;
  address public bridgedUSDC;
  address public bridgedEUROC;

  //other contracts
  address public brokerProxy;
  address public biPoolManagerProxy;
  address payable public reserveProxy;
  address payable public partialReserveProxy;

  address public grandaMentoProxy;
  address public exchangeProxy;
  address public exchangeEURProxy;
  address public exchangeBRLProxy;

  address public oldMainReserveMultisig;
  address public partialReserveMultisig;
  address public newReserveImplementation;

  address public freezerProxy;
  address public validators;

  // Helper mapping to store the exchange IDs for the reference rate feeds
  mapping(address => bytes32) public referenceRateFeedIDToExchangeId;

  bool public hasChecks = true;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
    setUpConfigs();
  }

  /**
   * @dev Loads the deployed contracts from the previous deployment step
   */
  function loadDeployedContracts() public {
    contracts.load("MU01-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");
    contracts.load("MU04-00-Create-Implementations", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // tokens
    stableTokenV2 = contracts.deployed("StableTokenV2");
    cUSDProxy = address(uint160(contracts.celoRegistry("StableToken")));
    cEURProxy = address(uint160(contracts.celoRegistry("StableTokenEUR")));
    cBRLProxy = address(uint160(contracts.celoRegistry("StableTokenBRL")));
    eXOFProxy = address(uint160(contracts.celoRegistry("StableTokenXOF")));
    celo = contracts.celoRegistry("GoldToken");
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    bridgedEUROC = contracts.dependency("BridgedEUROC");

    // other contracts
    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    reserveProxy = address(uint160(contracts.celoRegistry("Reserve")));
    partialReserveProxy = address(uint160(contracts.deployed("PartialReserveProxy")));

    exchangeProxy = contracts.celoRegistry("Exchange");
    exchangeEURProxy = contracts.celoRegistry("ExchangeEUR");
    exchangeBRLProxy = contracts.celoRegistry("ExchangeBRL");
    grandaMentoProxy = contracts.celoRegistry("GrandaMento");

    oldMainReserveMultisig = 0x554Fca0f7c465cd2F8C305a10bF907A2034d2a19;
    partialReserveMultisig = contracts.dependency("PartialReserveMultisig");
    newReserveImplementation = IProxy(partialReserveProxy)._getImplementation();

    freezerProxy = contracts.celoRegistry("Freezer");
    validators = contracts.celoRegistry("Validators");
  }

  /**
   * @dev Setups up various configuration structs.
   *      This function is called by the governance script runner.
   */
  function setUpConfigs() public {
    // Create pool configurations
    MU04Config.MU04 memory config = MU04Config.get(contracts);

    // Set the exchange ID for the reference rate feed
    for (uint i = 0; i < config.pools.length; i++) {
      referenceRateFeedIDToExchangeId[config.pools[i].referenceRateFeedID] = getExchangeId(
        config.pools[i].asset0,
        config.pools[i].asset1,
        config.pools[i].isConstantSum
      );
    }
  }

  function run() public {
    prepare();
    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "MU04", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    MU04Config.MU04 memory config = MU04Config.get(contracts);

    proposal_updateStableTokenImplementations();
    proposal_initilizeStableTokenV2();
    proposal_freezeExchanges();
    proposal_updateRegistry();
    proposal_updateReserveImplementation();
    proposal_updateReserveExchangeSpender();
    proposal_configureReserveCollateralAssets();
    proposal_addEXOFToMainReserve();
    proposal_updateReserveSpenders();
    proposal_updateReserveInBroker();
    proposal_updateReserveInBiPoolManager();
    proposal_updateTradingLimits(config);

    return transactions;
  }

  /**
   * @dev updates StableToken Proxies to use StableTokenV2 as their implementation
   */
  function proposal_updateStableTokenImplementations() private {
    address[] memory stableTokenProxies = Arrays.addresses(cUSDProxy, cEURProxy, cBRLProxy, eXOFProxy);

    for (uint i = 0; i < stableTokenProxies.length; i++) {
      address payable proxyPayable = address(uint160(stableTokenProxies[i]));

      if (IProxy(proxyPayable)._getImplementation() != stableTokenV2) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            proxyPayable,
            abi.encodeWithSelector(IProxy(0)._setImplementation.selector, stableTokenV2)
          )
        );
      }
    }
  }

  /**
   * @dev Initializes StableTokenV2 with the correct parameters
   */
  function proposal_initilizeStableTokenV2() private {
    address[] memory stableTokens = Arrays.addresses(cUSDProxy, cEURProxy, cBRLProxy, eXOFProxy);

    for (uint i = 0; i < stableTokens.length; i++) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          stableTokens[i],
          abi.encodeWithSelector(
            IStableTokenV2(0).initializeV2.selector,
            brokerProxy,
            validators,
            address(0) // exchange contracts are deprecated
          )
        )
      );
    }
  }

  /**
   * @dev Freezes all exchanges in order to deprecate Mento V1
   */
  function proposal_freezeExchanges() private {
    address[] memory exchangesV1 = Arrays.addresses(exchangeProxy, exchangeEURProxy, exchangeBRLProxy);

    for (uint i = 0; i < exchangesV1.length; i++) {
      if (!IFreezer(freezerProxy).isFrozen(exchangesV1[i])) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            freezerProxy,
            abi.encodeWithSelector(IFreezer(0).freeze.selector, exchangesV1[i])
          )
        );
      }
    }
  }

  /**
   * @dev Removes MentoV1 exchanges from the registry
   */
  function proposal_updateRegistry() private {
    bytes32[] memory exchangesV1 = Arrays.bytes32s("Exchange", "ExchangeEUR", "ExchangeBRL", "GrandaMento");
    for (uint i = 0; i < exchangesV1.length; i++) {
      if (IRegistry(REGISTRY_ADDRESS).getAddressForString(bytes32ToStr(exchangesV1[i])) != address(0)) {
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            REGISTRY_ADDRESS,
            abi.encodeWithSelector(IRegistry(0).setAddressFor.selector, bytes32ToStr(exchangesV1[i]), address(0))
          )
        );
      }
    }
  }

  /**
   * @dev Updates main reserve to use the new reserve implementation
   */
  function proposal_updateReserveImplementation() private {
    if (IProxy(reserveProxy)._getImplementation() != newReserveImplementation) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(IProxy(0)._setImplementation.selector, newReserveImplementation)
        )
      );
    }
  }

  /**
   * @dev Removes legacy exchanges from reserve spender list and adds broker
   */
  function proposal_updateReserveExchangeSpender() private {
    // removing all configured exchanges here since after MU04 the Broker should be the only active exchange
    // currently we have different configurations across different chains.
    address[] memory exchangeSpenders = Reserve(reserveProxy).getExchangeSpenders();
    for (int i = int(exchangeSpenders.length) - 1; i >= 0; i--) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(Reserve(0).removeExchangeSpender.selector, exchangeSpenders[uint256(i)], uint256(i))
        )
      );
    }

    if (!Reserve(reserveProxy).isExchangeSpender(brokerProxy)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(Reserve(0).addExchangeSpender.selector, brokerProxy)
        )
      );
    }
  }

  /**
   * @dev Configure reserve collateral assets and spending ratios
   */
  function proposal_configureReserveCollateralAssets() private {
    address[] memory collateralAssets = Arrays.addresses(celo, bridgedUSDC, bridgedEUROC);
    uint[] memory spendingRatios = Arrays.uints(1e24 * 0.2, 1e24, 1e24);

    for (uint i = 0; i < collateralAssets.length; i++) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(Reserve(0).addCollateralAsset.selector, collateralAssets[i])
        )
      );
    }

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        reserveProxy,
        abi.encodeWithSelector(
          Reserve(0).setDailySpendingRatioForCollateralAssets.selector,
          collateralAssets,
          spendingRatios
        )
      )
    );
  }

  /**
   * @dev Updates reserve tokens to include eXOF
   */
  function proposal_addEXOFToMainReserve() private {
    if (!Reserve(reserveProxy).isToken(eXOFProxy)) {
      transactions.push(
        ICeloGovernance.Transaction(0, reserveProxy, abi.encodeWithSelector(Reserve(0).addToken.selector, eXOFProxy))
      );
    }
  }

  /**
   * @dev Updates reserve spenders
   */
  function proposal_updateReserveSpenders() private {
    // remove outdated reserve spender multisig
    if (Reserve(reserveProxy).isSpender(oldMainReserveMultisig)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(Reserve(0).removeSpender.selector, oldMainReserveMultisig, 0)
        )
      );
    }

    // add new reserve spender multisig
    if (!Reserve(reserveProxy).isSpender(partialReserveMultisig)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(Reserve(0).addSpender.selector, partialReserveMultisig)
        )
      );
    }
  }

  /**
   * @dev Updates reserve in broker to use the main reserve
   */
  function proposal_updateReserveInBroker() private {
    if (address(Broker(brokerProxy).reserve()) == partialReserveProxy) {
      transactions.push(
        ICeloGovernance.Transaction(0, brokerProxy, abi.encodeWithSelector(Broker(0).setReserve.selector, reserveProxy))
      );
    }
  }

  /**
   * @dev Updates reserve in BiPoolManager to use the main reserve
   */
  function proposal_updateReserveInBiPoolManager() private {
    if (address(BiPoolManager(biPoolManagerProxy).reserve()) == partialReserveProxy) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          biPoolManagerProxy,
          abi.encodeWithSelector(BiPoolManager(0).setReserve.selector, reserveProxy)
        )
      );
    }
  }

  /**
   * @dev Updates trading limits to increase MentoV2 volume
   */
  function proposal_updateTradingLimits(MU04Config.MU04 memory config) private {
    for (uint256 i = 0; i < config.pools.length; i++) {
      Config.Pool memory poolConfig = config.pools[i];

      bytes32 limit0Id = referenceRateFeedIDToExchangeId[poolConfig.referenceRateFeedID] ^
        bytes32(uint256(uint160(poolConfig.asset0)));

      if (!isSameTradingLimitConfig(limit0Id, poolConfig.asset0limits)) {
        // update the trading limits on asset0 of the pool
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            brokerProxy,
            abi.encodeWithSelector(
              Broker(0).configureTradingLimit.selector,
              referenceRateFeedIDToExchangeId[poolConfig.referenceRateFeedID],
              poolConfig.asset0,
              TradingLimits.Config({
                timestep0: poolConfig.asset0limits.timeStep0,
                timestep1: poolConfig.asset0limits.timeStep1,
                limit0: poolConfig.asset0limits.limit0,
                limit1: poolConfig.asset0limits.limit1,
                limitGlobal: poolConfig.asset0limits.limitGlobal,
                flags: Config.tradingLimitConfigToFlag(poolConfig.asset0limits)
              })
            )
          )
        );
      }
      bytes32 limit1Id = referenceRateFeedIDToExchangeId[poolConfig.referenceRateFeedID] ^
        bytes32(uint256(uint160(poolConfig.asset1)));

      if (!isSameTradingLimitConfig(limit1Id, poolConfig.asset1limits)) {
        // update trading limits on asset1 of the pool
        transactions.push(
          ICeloGovernance.Transaction(
            0,
            brokerProxy,
            abi.encodeWithSelector(
              Broker(0).configureTradingLimit.selector,
              referenceRateFeedIDToExchangeId[poolConfig.referenceRateFeedID],
              poolConfig.asset1,
              TradingLimits.Config({
                timestep0: poolConfig.asset1limits.timeStep0,
                timestep1: poolConfig.asset1limits.timeStep1,
                limit0: poolConfig.asset1limits.limit0,
                limit1: poolConfig.asset1limits.limit1,
                limitGlobal: poolConfig.asset1limits.limitGlobal,
                flags: Config.tradingLimitConfigToFlag(poolConfig.asset1limits)
              })
            )
          )
        );
      }
    }
  }

  /**
   * @notice Helper function to get the exchange ID for a pool.
   */
  function getExchangeId(address asset0, address asset1, bool isConstantSum) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          IERC20Metadata(asset0).symbol(),
          IERC20Metadata(asset1).symbol(),
          isConstantSum ? "ConstantSum" : "ConstantProduct"
        )
      );
  }

  /**
   * @notice Helper function that compares current trading limits config with the expected config.
   * this is used to determin whether TradingLimits need to be updated.
   */
  function isSameTradingLimitConfig(
    bytes32 configId,
    Config.TradingLimit memory newConfig
  ) internal view returns (bool) {
    (uint32 timestamp0, uint32 timestamp1, int48 limit0, int48 limit1, int48 limitGlobal, uint8 flags) = Broker(
      brokerProxy
    ).tradingLimitsConfig(configId);
    if (flags != Config.tradingLimitConfigToFlag(newConfig)) return false;
    if (timestamp0 != newConfig.timeStep0) return false;
    if (timestamp1 != newConfig.timeStep1) return false;
    if (limit0 != newConfig.limit0) return false;
    if (limit1 != newConfig.limit1) return false;
    if (limitGlobal != newConfig.limitGlobal) return false;
    return true;
  }

  function bytes32ToStr(bytes32 _bytes32) public view returns (string memory) {
    uint256 length = 0;
    while (bytes1(_bytes32[length]) != 0) {
      length++;
    }

    bytes memory bytesArray = new bytes(length);
    for (uint256 i; i < length; i++) {
      bytesArray[i] = _bytes32[i];
    }
    return string(bytesArray);
  }
}
