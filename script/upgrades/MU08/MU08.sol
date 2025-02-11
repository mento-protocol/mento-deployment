// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IReserve } from "mento-core-2.6.0/interfaces/IReserve.sol";

interface IOwnableLite {
  function owner() external view returns (address);

  function transferOwnership(address recipient) external;
}

interface IProxyLite {
  function _getImplementation() external view returns (address);

  function _getOwner() external view returns (address);

  function _transferOwnership(address) external;

  function _setAndInitializeImplementation(address, bytes calldata) external payable;
}

contract MU08 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  // Celo Governance:
  address private celoGovernance;

  // Celo Registry:
  address private celoRegistry;

  // Mento contracts:

  //Tokens:
  address private CELOProxy;
  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address private eXOFProxy;
  address private cKESProxy;
  address private PUSOProxy;
  address private cCOPProxy;
  address private cGHSProxy;

  // MentoV2 contracts:
  address private brokerProxy;
  address private biPoolManagerProxy;
  address private reserveProxy;
  address private breakerBox;
  address private medianDeltaBreaker;
  address private valueDeltaBreaker;

  // MentoV1 contracts:
  address private exchangeProxy;
  address private exchangeEURProxy;
  address private exchangeBRLProxy;
  address private grandaMentoProxy;

  // MentoGovernance contracts:
  address private governanceFactory;
  address private timelockProxy;

  // Mento Reserve Multisig address:
  address private reserveMultisig;

  // Celo Custody Reserve address:
  address private celoCustodyReserve;

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  /**
   * @dev Loads the deployed contracts from previous deployments
   */
  function loadDeployedContracts() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("cKES-00-Create-Proxies", "latest");
    contracts.loadSilent("PUSO-00-Create-Proxies", "latest");
    contracts.loadSilent("cCOP-00-Create-Proxies", "latest");
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");
    contracts.loadSilent("MU08-00-Create-Proxies", "latest");
    contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    // Celo Governance:
    celoGovernance = contracts.celoRegistry("Governance");

    // Celo Registry:
    celoRegistry = 0x000000000000000000000000000000000000ce10;

    // Tokens:
    CELOProxy = address(uint160(contracts.celoRegistry("GoldToken")));
    cUSDProxy = address(uint160(contracts.celoRegistry("StableToken")));
    cEURProxy = address(uint160(contracts.celoRegistry("StableTokenEUR")));
    cBRLProxy = address(uint160(contracts.celoRegistry("StableTokenBRL")));
    eXOFProxy = address(uint160(contracts.deployed("StableTokenXOFProxy")));
    cKESProxy = address(uint160(contracts.deployed("StableTokenKESProxy")));
    PUSOProxy = address(uint160(contracts.deployed("StableTokenPHPProxy")));
    cCOPProxy = address(uint160(contracts.deployed("StableTokenCOPProxy")));
    cGHSProxy = address(uint160(contracts.deployed("StableTokenGHSProxy")));

    // MentoV2 contracts:
    brokerProxy = address(uint160(contracts.deployed("BrokerProxy")));
    biPoolManagerProxy = address(uint160(contracts.deployed("BiPoolManagerProxy")));
    reserveProxy = address(uint160(contracts.celoRegistry("Reserve")));
    breakerBox = address(uint160(contracts.deployed("BreakerBox")));
    medianDeltaBreaker = address(uint160(contracts.deployed("MedianDeltaBreaker")));
    valueDeltaBreaker = address(uint160(contracts.deployed("ValueDeltaBreaker")));

    // MentoV1 contracts:
    exchangeProxy = contracts.dependency("Exchange");
    exchangeEURProxy = contracts.dependency("ExchangeEUR");
    exchangeBRLProxy = contracts.dependency("ExchangeBRL");
    grandaMentoProxy = contracts.dependency("GrandaMento");

    // MentoGovernance contracts:
    governanceFactory = contracts.deployed("GovernanceFactory");
    timelockProxy = IGovernanceFactory(governanceFactory).governanceTimelock();

    // Mento Reserve Multisig address:
    reserveMultisig = contracts.dependency("PartialReserveMultisig");

    // Celo Custody Reserve address:
    celoCustodyReserve = address(uint160(contracts.deployed("ReserveProxy")));
  }

  function run() public {
    prepare();

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(
        _transactions,
        "https://github.com/celo-org/governance/blob/main/CGPs/cgp-0156.md",
        celoGovernance
      );
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    proposal_initializeCustodyReserve();
    proposal_configureCustodyReserve();
    proposal_configureMentoReserve();
    proposal_transferCeloToCustodyReserve();
    proposal_updateReserveSpenders();
    proposal_transferCustodyReserveOwnership();

    proposal_updateOtherReserveAddresses();
    proposal_transferTokenOwnership();
    proposal_transferMentoV2Ownership();
    proposal_transferMentoV1Ownership();
    proposal_transferGovFactoryOwnership();

    return transactions;
  }

  function proposal_initializeCustodyReserve() public {
    address reserveImplementation = IProxyLite(reserveProxy)._getImplementation();

    if (IProxyLite(celoCustodyReserve)._getImplementation() == address(0)) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          celoCustodyReserve,
          abi.encodeWithSelector(
            IProxyLite(0)._setAndInitializeImplementation.selector,
            reserveImplementation,
            abi.encodeWithSelector(
              IReserve(0).initialize.selector,
              celoRegistry, // celo registry address
              3153600000, // 100 years non relevant copied from main reserve config
              FixidityLib.fixed1().unwrap(), // 100% CELO spending
              0, // no frozen gold
              0, // no frozen days
              Arrays.bytes32s(bytes32("cGLD")), // only CELO collateral asset
              Arrays.uints(FixidityLib.fixed1().unwrap()), // 100% weight
              FixidityLib.newFixed(0).unwrap(), // disabled tobin tax
              FixidityLib.newFixed(0).unwrap(), // disabled tobin tax reserve ratio
              Arrays.addresses(CELOProxy), // CELO only collateral asset
              Arrays.uints(FixidityLib.fixed1().unwrap()) // 100% daily spending ratio
            )
          )
        )
      );
    }
  }

  function proposal_configureCustodyReserve() public {
    // set celo gov as spender on custody reserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        celoCustodyReserve,
        abi.encodeWithSelector(IReserve(0).addSpender.selector, celoGovernance)
      )
    );

    // set celo gov as other reserve address on custody reserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        celoCustodyReserve,
        abi.encodeWithSelector(IReserve(0).addOtherReserveAddress.selector, celoGovernance)
      )
    );
  }

  function proposal_configureMentoReserve() public {
    // set celo gov as spender on mento reserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        reserveProxy,
        abi.encodeWithSelector(IReserve(0).addSpender.selector, celoGovernance)
      )
    );

    // set custody reserve as other reserve address on mento reserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        reserveProxy,
        abi.encodeWithSelector(IReserve(0).addOtherReserveAddress.selector, celoCustodyReserve)
      )
    );

    // set CELO spending ratio to 100% on mento reserve
    if (IReserve(reserveProxy).getDailySpendingRatioForCollateralAsset(CELOProxy) != FixidityLib.fixed1().unwrap()) {
      transactions.push(
        ICeloGovernance.Transaction(
          0,
          reserveProxy,
          abi.encodeWithSelector(
            IReserve(0).setDailySpendingRatioForCollateralAssets.selector,
            Arrays.addresses(CELOProxy),
            Arrays.uints(FixidityLib.fixed1().unwrap())
          )
        )
      );
    }
  }

  function proposal_transferCeloToCustodyReserve() public {
    uint256 fullReturnAmount = 85941499340972869827370586; // 85.9M CELO
    uint256 firstReturnAmount = 20_000_000 * 1e18;

    require(fullReturnAmount <= IReserve(reserveProxy).getUnfrozenBalance(), "Not enough CELO in main reserve");

    // transfer ~85.9M CELO to custody reserve from main reserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        reserveProxy,
        abi.encodeWithSelector(
          IReserve(0).transferCollateralAsset.selector,
          CELOProxy,
          celoCustodyReserve,
          fullReturnAmount
        )
      )
    );

    // transfer 20M CELO to celo gov from custody reserve;
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        celoCustodyReserve,
        abi.encodeWithSelector(
          IReserve(0).transferCollateralAsset.selector,
          CELOProxy,
          celoGovernance,
          firstReturnAmount
        )
      )
    );
  }

  function proposal_updateReserveSpenders() public {
    // remove celo gov as spender on mento reserve
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        reserveProxy,
        abi.encodeWithSelector(IReserve(0).removeSpender.selector, celoGovernance)
      )
    );

    // remove custody reserve as other reserve address on mento reserve
    address[] memory otherReserves = IReserve(reserveProxy).getOtherReserveAddresses();

    transactions.push(
      ICeloGovernance.Transaction(
        0,
        reserveProxy,
        abi.encodeWithSelector(IReserve(0).removeOtherReserveAddress.selector, celoCustodyReserve, otherReserves.length)
      )
    );
  }

  function proposal_transferCustodyReserveOwnership() public {
    // transfer ownership of celo custody reserve to mento gov
    transactions.push(
      ICeloGovernance.Transaction({
        value: 0,
        destination: celoCustodyReserve,
        data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
      })
    );
  }

  function proposal_updateOtherReserveAddresses() public {
    // remove anchorage addressess
    address[] memory otherReserves = IReserve(reserveProxy).getOtherReserveAddresses();
    for (uint256 i = 0; i < otherReserves.length; i++) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: reserveProxy,
          // we remove the first index(0) in the list for each iteration because the index changes after each removal
          data: abi.encodeWithSelector(IReserve(0).removeOtherReserveAddress.selector, otherReserves[i], 0)
        })
      );
    }
    // add reserve multisig
    transactions.push(
      ICeloGovernance.Transaction({
        value: 0,
        destination: reserveProxy,
        data: abi.encodeWithSelector(IReserve(0).addOtherReserveAddress.selector, reserveMultisig)
      })
    );
  }

  function proposal_transferTokenOwnership() public {
    address[] memory tokenProxies = Arrays.addresses(
      cUSDProxy,
      cEURProxy,
      cBRLProxy,
      eXOFProxy,
      cKESProxy,
      PUSOProxy,
      cCOPProxy,
      cGHSProxy
    );
    for (uint i = 0; i < tokenProxies.length; i++) {
      transferOwnership(tokenProxies[i]);
      transferProxyAdmin(tokenProxies[i]);
    }

    // All the token proxies are pointing to the same StableTokenV2 implementation (cUSD)
    // so we only need to transfer ownership of that single contract.
    address sharedImplementation = IProxyLite(cUSDProxy)._getImplementation();
    for (uint i = 0; i < tokenProxies.length; i++) {
      if (tokenProxies[i] == cGHSProxy) {
        // cGHS is not yet initialized, so it doesn't have an implementation
        continue;
      }

      require(
        IProxyLite(tokenProxies[i])._getImplementation() == sharedImplementation,
        "Token proxies not poiting to cUSD implementation"
      );
    }
    transferOwnership(sharedImplementation);
  }

  function proposal_transferMentoV2Ownership() public {
    address[] memory mentoV2Proxies = Arrays.addresses(brokerProxy, biPoolManagerProxy, reserveProxy);
    for (uint i = 0; i < mentoV2Proxies.length; i++) {
      transferOwnership(mentoV2Proxies[i]);
      transferProxyAdmin(mentoV2Proxies[i]);
      address implementation = IProxyLite(mentoV2Proxies[i])._getImplementation();
      transferOwnership(implementation);
    }

    address[] memory mentoV2NonupgradeableContracts = Arrays.addresses(
      breakerBox,
      medianDeltaBreaker,
      valueDeltaBreaker
    );
    for (uint i = 0; i < mentoV2NonupgradeableContracts.length; i++) {
      transferOwnership(mentoV2NonupgradeableContracts[i]);
    }
  }

  function proposal_transferMentoV1Ownership() public {
    // For some reason Mento V1 implementation contracts were not transferred to Celo Governance and are
    // owned by the original deployer address. Therefore we can only transfer ownership of the proxies.
    address[] memory mentoV1Proxies = Arrays.addresses(
      exchangeProxy,
      exchangeEURProxy,
      exchangeBRLProxy,
      grandaMentoProxy
    );
    for (uint i = 0; i < mentoV1Proxies.length; i++) {
      transferOwnership(mentoV1Proxies[i]);
      transferProxyAdmin(mentoV1Proxies[i]);
    }
  }

  function proposal_transferGovFactoryOwnership() public {
    transferOwnership(governanceFactory);
  }

  function transferOwnership(address contractAddr) internal {
    bool isGHS = contractAddr == cGHSProxy;

    if (
      isGHS ||
      (IOwnableLite(contractAddr).owner() != timelockProxy && IOwnableLite(contractAddr).owner() == celoGovernance)
    ) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: contractAddr,
          data: abi.encodeWithSelector(IOwnableLite(0).transferOwnership.selector, timelockProxy)
        })
      );
    }
  }

  function transferProxyAdmin(address contractAddr) internal {
    bool isGHS = contractAddr == cGHSProxy;

    if (
      isGHS ||
      (IProxyLite(contractAddr)._getOwner() != timelockProxy && IProxyLite(contractAddr)._getOwner() == celoGovernance)
    ) {
      transactions.push(
        ICeloGovernance.Transaction({
          value: 0,
          destination: contractAddr,
          data: abi.encodeWithSelector(IProxyLite(0)._transferOwnership.selector, timelockProxy)
        })
      );
    }
  }
}
