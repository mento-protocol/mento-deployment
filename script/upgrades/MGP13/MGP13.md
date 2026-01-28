## TL;DR

This proposal enables a 5bps (0.05%) spread fee and increases the ValueDeltaBreaker circuit breaker thresholds from 10bps to 15bps (0.10% → 0.15%) for the following pairs: `USDm/USDC`, `USDm/axlUSDC`, and `USDm/USD₮`. The goals are to reduce breaker-induced downtime, curb arbitrage losses, and introduce protocol revenue on high-volume pairs.

### Summary

This proposal updates two parameter sets for the above‑mentioned USDm pairs:

- **Spread fee**: **0.00% → 0.05%** (0bps → 5bps)
- **Circuit breaker threshold**: **0.10% → 0.15%** (10bps → 15bps)

These changes are proposed because the current 10bps breaker causes significant downtime (notably for the USD₮ pair), and the 0% spread exposes the reserve to fee‑free arbitrage losses while generating no protocol revenue.

The current BiPoolManager implementation does not allow updating a pool’s spread directly; it requires fully destroying and re‑creating the exchange. To simplify this proposal, a temporary BiPoolManager implementation has been deployed that exposes a `setSpread(exchangeId, newSpread)` setter. This temporary implementation is used only to update the spreads; the BiPoolManager is then reverted to its original implementation as part of this proposal. The temporary implementation has been deployed and verified at: [0xC016174B60519Bdc24433d4ed2cFf6c1efaC7881](https://celoscan.io/address/0xC016174B60519Bdc24433d4ed2cFf6c1efaC7881)

#### Affected Pools

| Pair         | Exchange ID                                                        | Current Spread | New Spread |
| ------------ | ------------------------------------------------------------------ | -------------- | ---------- |
| USDm/USDC    | 0xacc988382b66ee5456086643dcfd9a5ca43dd8f428f6ef22503d8b8013bcffd7 | 0.00%          | 0.05%      |
| USDm/axlUSDC | 0x0d739efbfc30f303e8d1976c213b4040850d1af40f174f4169b846f6fd3d2f20 | 0.00%          | 0.05%      |
| USDm/USD₮    | 0x773bcec109cee923b5e04706044fd9d6a5121b1a6a4c059c36fdbe5b845d4e9b | 0.00%          | 0.05%      |

#### Value Delta Breaker Thresholds

| Rate Feed (Pair) | Rate Feed ID                               | Current | New   |
| ---------------- | ------------------------------------------ | ------- | ----- |
| USDC/USD         | 0xA1A8003936862E7a15092A91898D69fa8bCE290c | 0.10%   | 0.15% |
| USDT/USD         | 0xE06C10C63377cD098b589c0b90314bFb55751558 | 0.10%   | 0.15% |

### Transaction Details

This proposal consists of **6 transactions**.

**Step 1: Switch to Temporary BiPoolManager Implementation**

- Call `_setImplementation(address)` on the BiPoolManager proxy to switch from the current implementation to a temporary BiPoolManager implementation that exposes `setSpread`.

**Step 2: Update Spreads for USDm Pairs**

For each exchange in the table above:

- Call `setSpread(bytes32 exchangeId, uint256 spread)` to set the spread to **5bps**

**Step 3: Update Value Delta Breaker Thresholds**

Circuit breakers are configured per rate feed. A single transaction updates both feeds:

- Set `USDC/USD` rate feed threshold to **15bps** (shared by `USDm/USDC` and `USDm/axlUSDC` exchanges)
- Set `USDT/USD` rate feed threshold to **15bps** (`USDm/USD₮` exchange)

**Step 4: Restore Original BiPoolManager Implementation**

- Call `_setImplementation(address)` on the BiPoolManager proxy to switch back to the original BiPoolManager implementation.

**Relevant Addresses for Verification**

- BiPoolManager (current implementation)

  - https://celoscan.io/address/0x22d9db95E6Ae61c104A7B6F6C78D7993B94ec901

- Temporary BiPoolManager implementation (with `setSpread()` function)

  - https://celoscan.io/address/0xC016174B60519Bdc24433d4ed2cFf6c1efaC7881

- ValueDeltaBreaker
  - https://celoscan.io/address/0x4DBC33B3abA78475A5AA4BC7A5B11445d387BF68
