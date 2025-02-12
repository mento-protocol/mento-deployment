### MGP04: Update governance voting period ahead of Celo L2 Transition

#### Description

With Celo's transition to an L2, the block time will be reduced from 5 seconds to 1 second. This proposal ensures that the governance voting period remains consistent after the upgrade, at approximately one week.

#### Changes

1. Adjust voting period to maintain one week duration:
   - On Celo mainnet, increase from 120,960 blocks to 604,800 blocks
   - Accounting for reduced block time (1s instead of 5s)

#### Motivation

- Preserve the one week voting period duration after the Celo blockchain's L2 transition

#### Technical Rationale

- Celo block time reduction from 5s to 1s necessitates voting period block count adjustment
- Current: 120,960 blocks at 5s per block ≈ 1 week
- Proposed: 604,800 blocks at 1s per block ≈ 1 week

#### Implementation Details

- One unique transaction:
  1. Update voting period in MentoGovernor contract

#### Testing

- Validate voting period with 1 second block time
