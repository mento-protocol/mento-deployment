### MGP03: Governance Adaptation for Celo L2 Transition

#### Description

With Celo's transition to an L2, the block time will be reduced from 5 seconds to 1 second. This proposal ensures that the governance voting period remains consistent at approximately one week, and provides MentoLabs with additional flexibility during the L2 transition.

#### Changes

1. Adjust voting period to maintain one week duration:
   - On Celo mainnet, increase from 120,960 blocks to 604,800 blocks
   - Accounting for reduced block time (1s instead of 5s)
2. Set the MentoLabs multisig address in the Locking contract
   - Enables MentoLabs to adjust locking parameters without full governance process

#### Motivation

- Preserve the one week voting period duration after the Celo blockchain's L2 transition
- Provide MentoLabs with operational flexibility during the critical L2 migration
- Ensure smooth transition during the blockchain upgrade

#### Technical Rationale

- Celo block time reduction from 5s to 1s necessitates voting period block count adjustment
- Current: 120,960 blocks at 5s per block ≈ 1 week
- Proposed: 604,800 blocks at 1s per block ≈ 1 week

#### Security Considerations

- Temporary enhanced multisig capabilities scoped to locking parameters
- Targeted approach to facilitate L2 transition management
- Preserves overall governance integrity while providing necessary flexibility

#### Implementation Details

- Two primary transactions:
  1. Update voting period in MentoGovernor contract
  2. Set MentoLabs multisig address in Locking contract with timing parameters adjustment rights

#### Testing

- Validate voting period with 1 second block time
- Confirm MentoLabs multisig can modify locking parameters

#### Future Outlook

- MentoLabs multisig priviliges will be revoked after successful transition
