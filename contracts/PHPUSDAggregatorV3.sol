// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { MockAggregatorV3 } from "lib/mento-core-develop/test/mocks/MockAggregatorV3.sol";

contract PHPUSDAggregatorV3 is MockAggregatorV3 {
  constructor() MockAggregatorV3(3) {}
}
