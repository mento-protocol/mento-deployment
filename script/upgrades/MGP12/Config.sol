// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;
import { Arrays } from "script/utils/Arrays.sol";

import { console2 } from "forge-std/console2.sol";
import { GovernanceScript } from "script/utils/mento/Script.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { IERC20Lite } from "script/interfaces/IERC20Lite.sol";

contract MGP12Config is GovernanceScript {
  uint256 public constant NUM_STABLES = 15;

  using Contracts for Contracts.Cache;

  struct TokenRenamingTask {
    string oldName;
    string newName;
    string oldSymbol;
    string newSymbol;
    address implementation;
  }

  address internal stableTokenV2ImplAddress;
  address internal renamerImplAddress;

  address[] internal stables;
  mapping(address => TokenRenamingTask) tasks;

  mapping(address => string) private rateFeedIdToName;

  address private cUSD;
  address private cEUR;
  address private cREAL;
  address private eXOF;
  address private cKES;
  address private PUSO;
  address private cCOP;
  address private cGHS;
  address private cGBP;
  address private cZAR;
  address private cCAD;
  address private cAUD;
  address private cCHF;
  address private cJPY;
  address private cNGN;

  function load() public {
    if (Chain.isCelo()) {
      loadMainetAddresses();
    } else if (Chain.isSepolia()) {
      loadSepoliaAddresses();
    } else {
      revert("Unexpected network for MGP12");
    }

    setStables();
    setTasks();
  }

  function setStables() public {
    stables.push(cUSD);
    stables.push(cEUR);
    stables.push(cREAL);
    stables.push(eXOF);
    stables.push(cKES);
    stables.push(PUSO);
    stables.push(cCOP);
    stables.push(cGHS);
    stables.push(cGBP);
    stables.push(cZAR);
    stables.push(cCAD);
    stables.push(cAUD);
    stables.push(cCHF);
    stables.push(cJPY);
    stables.push(cNGN);
  }

  function setTasks() public {
    tasks[cUSD].oldName = "Celo Dollar";
    tasks[cUSD].newName = "Mento Dollar";
    tasks[cUSD].oldSymbol = "cUSD";
    tasks[cUSD].newSymbol = "USDm";

    tasks[cEUR].oldName = "Celo Euro";
    tasks[cEUR].newName = "Mento Euro";
    tasks[cEUR].oldSymbol = "cEUR";
    tasks[cEUR].newSymbol = "EURm";

    tasks[cREAL].oldName = "Celo Brazilian Real";
    tasks[cREAL].newName = "Mento Brazilian Real";
    tasks[cREAL].oldSymbol = "cREAL";
    tasks[cREAL].newSymbol = "BRLm";

    tasks[eXOF].oldName = "ECO CFA";
    tasks[eXOF].newName = "Mento West African CFA franc";
    tasks[eXOF].oldSymbol = "eXOF";
    tasks[eXOF].newSymbol = "XOFm";

    tasks[cKES].oldName = "Celo Kenyan Shilling";
    tasks[cKES].newName = "Mento Kenyan Shilling";
    tasks[cKES].oldSymbol = "cKES";
    tasks[cKES].newSymbol = "KESm";

    tasks[PUSO].oldName = "PUSO";
    tasks[PUSO].newName = "Mento Philippine Peso";
    tasks[PUSO].oldSymbol = "PUSO";
    tasks[PUSO].newSymbol = "PHPm";

    tasks[cCOP].oldName = "Celo Colombian Peso";
    tasks[cCOP].newName = "Mento Colombian Peso";
    tasks[cCOP].oldSymbol = "cCOP";
    tasks[cCOP].newSymbol = "COPm";

    tasks[cGHS].oldName = "Celo Ghanaian Cedi";
    tasks[cGHS].newName = "Mento Ghanaian Cedi";
    tasks[cGHS].oldSymbol = "cGHS";
    tasks[cGHS].newSymbol = "GHSm";

    tasks[cGBP].oldName = "Celo British Pound";
    tasks[cGBP].newName = "Mento British Pound";
    tasks[cGBP].oldSymbol = "cGBP";
    tasks[cGBP].newSymbol = "GBPm";

    tasks[cZAR].oldName = "Celo South African Rand";
    tasks[cZAR].newName = "Mento South African Rand";
    tasks[cZAR].oldSymbol = "cZAR";
    tasks[cZAR].newSymbol = "ZARm";

    tasks[cCAD].oldName = "Celo Canadian Dollar";
    tasks[cCAD].newName = "Mento Canadian Dollar";
    tasks[cCAD].oldSymbol = "cCAD";
    tasks[cCAD].newSymbol = "CADm";

    tasks[cAUD].oldName = "Celo Australian Dollar";
    tasks[cAUD].newName = "Mento Australian Dollar";
    tasks[cAUD].oldSymbol = "cAUD";
    tasks[cAUD].newSymbol = "AUDm";

    tasks[cCHF].oldName = "Celo Swiss Franc";
    tasks[cCHF].newName = "Mento Swiss Franc";
    tasks[cCHF].oldSymbol = "cCHF";
    tasks[cCHF].newSymbol = "CHFm";

    tasks[cJPY].oldName = "Celo Japanese Yen";
    tasks[cJPY].newName = "Mento Japanese Yen";
    tasks[cJPY].oldSymbol = "cJPY";
    tasks[cJPY].newSymbol = "JPYm";

    tasks[cNGN].oldName = "Celo Nigerian Naira";
    tasks[cNGN].newName = "Mento Nigerian Naira";
    tasks[cNGN].oldSymbol = "cNGN";
    tasks[cNGN].newSymbol = "NGNm";
  }

  function loadMainetAddresses() public {
    contracts.loadSilent("cKES-00-Create-Proxies", "latest");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("PUSO-00-Create-Proxies", "latest");
    contracts.loadSilent("cCOP-00-Create-Proxies", "latest");
    contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");
    contracts.loadSilent("FX00-00-Deploy-Proxys", "latest");
    contracts.loadSilent("FX02-00-Deploy-Proxys", "latest");

    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    cREAL = contracts.celoRegistry("StableTokenBRL");
    eXOF = contracts.deployed("StableTokenXOFProxy");
    cKES = contracts.deployed("StableTokenKESProxy");
    PUSO = contracts.deployed("StableTokenPHPProxy");
    cCOP = contracts.deployed("StableTokenCOPProxy");
    cGHS = contracts.deployed("StableTokenGHSProxy");
    cGBP = contracts.deployed("StableTokenGBPProxy");
    cZAR = contracts.deployed("StableTokenZARProxy");
    cCAD = contracts.deployed("StableTokenCADProxy");
    cAUD = contracts.deployed("StableTokenAUDProxy");
    cCHF = contracts.deployed("StableTokenCHFProxy");
    cJPY = contracts.deployed("StableTokenJPYProxy");
    cNGN = contracts.deployed("StableTokenNGNProxy");

    contracts.loadSilent("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment
    stableTokenV2ImplAddress = contracts.deployed("StableTokenV2");

    contracts.loadSilent("MGP12-00-Rename-Implementation", "latest");
    renamerImplAddress = contracts.deployed("StableTokenV2Renamer");
  }

  function loadSepoliaAddresses() public {
    cUSD = contracts.dependency("StableTokenUSD");
    cEUR = contracts.dependency("StableTokenEUR");
    cREAL = contracts.dependency("StableTokenBRL");
    eXOF = contracts.dependency("StableTokenXOF");
    cKES = contracts.dependency("StableTokenKES");
    PUSO = contracts.dependency("StableTokenPHP");
    cCOP = contracts.dependency("StableTokenCOP");
    cGHS = contracts.dependency("StableTokenGHS");
    cGBP = contracts.dependency("StableTokenGBP");
    cZAR = contracts.dependency("StableTokenZAR");
    cCAD = contracts.dependency("StableTokenCAD");
    cAUD = contracts.dependency("StableTokenAUD");
    cCHF = contracts.dependency("StableTokenCHF");
    cJPY = contracts.dependency("StableTokenJPY");
    cNGN = contracts.dependency("StableTokenNGN");

    stableTokenV2ImplAddress = contracts.dependency("StableTokenV2Implementation");

    contracts.loadSilent("MGP12-00-Rename-Implementation", "latest");
    renamerImplAddress = contracts.deployed("StableTokenV2Renamer");
  }

  function getStables() public view returns (address[] memory) {
    return stables;
  }

  function getStableTokenV2ImplAddress() public view returns (address) {
    return stableTokenV2ImplAddress;
  }

  function getRenamerImplAddress() public view returns (address) {
    return renamerImplAddress;
  }

  function hasTask(address token) public view returns (bool) {
    return bytes(tasks[token].newName).length > 0;
  }

  function getTask(address token) public view returns (TokenRenamingTask memory) {
    require(hasTask(token), "Renaming task not found");

    return tasks[token];
  }

  function padRight(string memory str, uint256 width) internal pure returns (string memory) {
    bytes memory strBytes = bytes(str);
    if (strBytes.length >= width) {
      return str;
    }

    bytes memory padded = new bytes(width);
    uint256 i;
    for (i = 0; i < strBytes.length; i++) {
      padded[i] = strBytes[i];
    }
    for (; i < width; i++) {
      padded[i] = " ";
    }
    return string(padded);
  }

  function printAllStables() public view {
    console2.log("=====================================================================================");
    console2.log("Address                                     Name                            Symbol");
    console2.log("=====================================================================================");

    for (uint256 i = 0; i < stables.length; i++) {
      address stable = stables[i];
      string memory symbol = IERC20Lite(stable).symbol();
      string memory name = IERC20Lite(stable).name();

      string memory line = string(abi.encodePacked(vm.toString(stable), "  ", padRight(name, 30), "  ", symbol));
      console2.log(line);
    }
  }
}
