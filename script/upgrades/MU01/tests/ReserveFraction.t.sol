
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test, console2, Vm } from "celo-foundry/Test.sol";
import { Exchange } from "mento-core/contracts/Exchange.sol";
import { Contracts as contracts } from "script/utils/Contracts.sol";
import { Arrays } from "script/utils/Arrays.sol";


contract ReserveFraction is Test {
    address[] exchangesV1;
    address exchange;
    address exchangeBRL;
    address exchangeEUR;

    function setUp () public {
      // vm.createSelectFork("https://baklava-forno.celo-testnet.org/", 16381000);
    //   console2.log(block.number);
    //   vm.roll(16381000);
      console2.log(block.number);
      exchangesV1 = Arrays.addresses(
     0x190480908c11Efca37EDEA4405f4cE1703b68b23,
     0x28e257d1E73018A116A7C68E9d07eba736D9Ec05,
     0xC200CD8ac71A63e38646C34b51ee3cBA159dB544
    );
    }

    function testExchangeReserveFraction() public {
    for(uint i = 0; i < exchangesV1.length; i++){
      Exchange exchange = Exchange(exchangesV1[i]);
    //   console2.log(exchange.Owner());
      console2.log(exchange.reserveFraction());
    }
    }

    // block - 16381002
    // 10000000000000000000000 - usd
    // 125000000000000000000 - brl
    // 2500000000000000000000 - eur

    // block- 16381000

    // mainnet
    // 20000000000000000000000 - 2e22
    // 5000000000000000000000 - 5e21
    //  - 5e21

    // tx hash
    // 0xb65b03b517ebc16cb7e2a4492f0871aca5e45554cb87f58b47ad029d5d053979

    // 2nd gov proposal

}

