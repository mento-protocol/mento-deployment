## TL;DR

This proposal removes the temporary permissions granted to the Mento Labs multisig over the Locking contract, which were established during Celo's L2 transition through MGP03. This also marks the first governance proposal after the successful L2 transition and serves as a confirmation of the governance system's functionality.

### Summary

Following the successful transition of Celo to L2 and the subsequent verification of the Locking contract's proper functionality with the new block times, it is time to remove the temporary administrative rights granted to the Mento Labs multisig through MGP03. All necessary parameter adjustments have been completed and tested, confirming the contract's compatibility with the new L2 environment.

The Locking contract has been operating as expected since the L2 transition, with locks functioning correctly under the new 1-second block time. Our testing has verified that:

- Existing locks maintained their integrity during the transition
- New locks are being created successfully
- The adjusted parameters are working as intended with the new block time

This proposal represents a milestone as it will be the first governance proposal executed after the L2 transition, providing a validation of the governance system's functionality in the new environment.

### Transaction Details

This proposal consists of one transaction:

**TX#0:** call the `setMentoLabsMultisig(address _mentoLabsMultisig)` function with a zero address

- Target: Locking Proxy contract
- Function: `setMentoLabsMultisig(address)`
- Parameter: `0x0000000000000000000000000000000000000000`

**Relevant Addresses for verification**

- Locking Proxy
  - [_0x001Bb66636dCd149A1A2bA8C50E408BdDd80279C_](https://celoscan.io/address/0x001Bb66636dCd149A1A2bA8C50E408BdDd80279C)

### Expected Outcome

Upon successful execution of this proposal:

1. The Mento Labs multisig will no longer have administrative rights over the Locking contract
2. The governance system will be confirmed to be functioning correctly in the post-L2 environment

This completes the temporary administrative arrangements that were put in place for the L2 transition and returns control to the governance system.
