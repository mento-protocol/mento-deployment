// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { ICeloGovernance } from "mento-core/contracts/governance/interfaces/ICeloGovernance.sol";

interface ICGPBuilder {
    function buildProposal() external returns (ICeloGovernance.Transaction[] memory);
    function prepare() external;
}