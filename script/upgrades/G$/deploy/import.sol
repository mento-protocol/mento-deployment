// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

// File needed to compile 0.8 contract from Mento Core without causing
// problems with different solidity versions.

import { Broker } from "mento-core-3.0.0/swap/Broker.sol";
import { GoodDollarExchangeProvider } from "mento-core-3.0.0/goodDollar/GoodDollarExchangeProvider.sol";
import { GoodDollarExpansionController } from "mento-core-3.0.0/goodDollar/GoodDollarExpansionController.sol";
import { StableTokenV2 } from "mento-core-3.0.0/tokens/StableTokenV2.sol";
