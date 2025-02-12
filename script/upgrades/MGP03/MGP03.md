### MGP03: Set Mento Labs multisig ahead of Celo L2 Transition

#### Description

With Celo's transition to an L2, the block time will be reduced from 5 seconds to 1 second. This proposal follows MGP02, where after upgrading the Locking implementation contract
to support the transition, a Mento Labs owned multisig will have temporary rights over certain functions in the Locking contract, to ensure the necessary post-upgrade parameters adjustments are made correctly.

#### Changes

1. Set the Mento Labs multisig address in the Locking contract
   - Enables Mento Labs to adjust locking parameters without full governance process

#### Motivation

- Provide Mento Labs with operational flexibility during the critical L2 migration
- Ensure smooth transition during the blockchain upgrade

#### Technical Rationale

- Celo block time reduction from 5s to 1s requires adjustments to the Locking contract, particularly in the way week numbers are calculated by the contract.

#### Security Considerations

- Temporary enhanced multisig capabilities scoped to locking parameters
- Targeted approach to facilitate L2 transition management
- Preserves overall governance integrity while providing necessary flexibility

#### Testing

- Confirm Mento Labs multisig is set correctly
- Confirm Mento Labs multisig can modify locking parameters

#### Future Outlook

- Mento Labs multisig priviliges will be revoked after successful transition
