## TL;DR

This proposal grants the Mento Labs multisig temporary permissions to pause and adjust the Locking contract parameters during Celo's L2 transition, and extends the governance voting period to 8 days to ensure the Celo community can participate in future Mento Governance proposals.

### Summary

With Celo's transition to an L2, the block time will decrease from [5 seconds to 1 second](https://docs.celo.org/cel2/whats-changed/l1-l2#blocks). Following MGP02, this proposal grants a Mento Labs-owned multisig temporary rights over specific Locking contract functions to manage post-upgrade parameter adjustments during the transition.

As outlined in MGP02, a new Locking contract implementation has been [deployed and verified](https://celoscan.io/address/0x5a2c50efa0f63f0f97da9f002fefef3f64ed7d46). The contract underwent an audit through the [Hats Finance protocol](https://app.hats.finance/audit-competitions/mento-0x2a1b9b1f6fa7c2e73815a7dff0e1688767382694/scope), revealing only three low-severity issues. The complete audit report is [available here](https://github.com/hats-finance/Mento-0x2a1b9b1f6fa7c2e73815a7dff0e1688767382694/blob/report-update-20250214T181014271Z/report.md). After the audit's completion, the [Locking proxy contract](https://celoscan.io/address/0x001Bb66636dCd149A1A2bA8C50E408BdDd80279C) was [upgraded](https://celoscan.io/tx/0x6f1e05b4882b9965e995785605893fa84734a2d6da7c5da254b48e87a4673689#eventlog#445) to this new implementation.

With the Locking contract upgrade complete, the next step is setting the Mento Labs multisig address in the contract. This multisig will have permission to pause the contract during the transition and adjust parameters to accommodate the new block time while maintaining compatibility with existing locks. The upgrade process was already tested and successfully executed on Alfajores. After completing the L2 upgrade and resuming the Locking contract, a follow-up proposal will be issued to return the Proxy admin rights granted in MGP02 and remove the Mento Labs multisig address established in this proposal.

Additionally, this proposal extends the governance voting period from 7 to 8 days, allowing the Celo community to participate in future Mento Governance proposals after the Mento protocol transitions to its own governance. The voting process is detailed in the Celo forum post: [Empowering the Celo Community with Mento Governance Rights](https://forum.celo.org/t/empowering-the-celo-community-with-mento-governance-rights/10122).

### Transaction Details

This proposal consists of two transactions:

**TX#0:** call the _setMentoLabsMultisig(address \_mentoLabsMultisig)_ function

- Verify the **Locking** address
- Verify the **Mento Labs Multisig** address

**TX#1:** call the _setVotingPeriod(uint256 newVotingPeriod)_ function in Governor

- Verify the **Governor** address
- Verify the **newVotingPeriod** parameter is 8 days (_138240_)
  - Parameter is configured in number of blocks based on the current 5s block time:
    _60 * 60 * 24 \* 8 / 5_

**Relevant Addresses for verification**

- Locking Proxy
  - [_0x001Bb66636dCd149A1A2bA8C50E408BdDd80279C_](https://celoscan.io/address/0x001Bb66636dCd149A1A2bA8C50E408BdDd80279C)
- Governor Proxy
  - [_0x47036d78bB3169b4F5560dD77BF93f4412A59852_](https://celoscan.io/address/0x47036d78bB3169b4F5560dD77BF93f4412A59852)
- Mento Labs Multisig (3/7 Multisig with Mento Labs employees)
  - [_0x655133d8E90F8190ed5c1F0f3710F602800C0150_](https://celoscan.io/address/0x655133d8E90F8190ed5c1F0f3710F602800C0150)

### Future Steps

After the Celo community announces the L2 transition block number, we will publish a forum post detailing the Locking contract pause timeline and specific actions to be taken by the Mento Labs multisig. For full transparency, all transactions executed by the Mento Labs multisig will be shared publicly for community verification.
