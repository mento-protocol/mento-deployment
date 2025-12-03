## TL;DR

This proposal rebrands all Mento stablecoins from the `cXXX` symbol convention to `XXXm`, aligning with Mento's multichain strategy and establishing a unified brand identity. For example, `cUSD` becomes `USDm`, `cEUR` becomes `EURm`, and so on. The token names are adjusted accordingly, i.e. `Celo Dollar` becomes `Mento Dollar` and so forth. This is a branding-only change with no modifications to smart contract addresses, collateralization mechanisms, or fiat pegs. Please see [the forum post](https://forum.mento.org/t/mento-stablecoin-rebranding-and-strategic-evolution/98) for more details on the proposal.

### Summary

As Mento evolves into a global FX layer with multichain capabilities, a unified naming convention is essential. The "m" suffix stands for "Mento-native" and signals that these assets are designed for use across multiple blockchain ecosystems.

This rebranding:

- Prepares Mento for seamless multichain adoption
- Strengthens Mento's independent brand identity
- Maintains full backwards compatibility — all contract addresses remain unchanged

The following tokens will be renamed:

| Current Symbol | Current Name            | New Symbol | New Name                     |
| -------------- | ----------------------- | ---------- | ---------------------------- |
| cUSD           | Celo Dollar             | USDm       | Mento Dollar                 |
| cEUR           | Celo Euro               | EURm       | Mento Euro                   |
| cREAL          | Celo Brazilian Real     | BRLm       | Mento Brazilian Real         |
| eXOF           | ECO CFA                 | XOFm       | Mento West African CFA franc |
| cKES           | Celo Kenyan Shilling    | KESm       | Mento Kenyan Shilling        |
| PUSO           | PUSO                    | PHPm       | Mento Philippine Peso        |
| cCOP           | Celo Colombian Peso     | COPm       | Mento Colombian Peso         |
| cGHS           | Celo Ghanaian Cedi      | GHSm       | Mento Ghanaian Cedi          |
| cGBP           | Celo British Pound      | GBPm       | Mento British Pound          |
| cZAR           | Celo South African Rand | ZARm       | Mento South African Rand     |
| cCAD           | Celo Canadian Dollar    | CADm       | Mento Canadian Dollar        |
| cAUD           | Celo Australian Dollar  | AUDm       | Mento Australian Dollar      |
| cCHF           | Celo Swiss Franc        | CHFm       | Mento Swiss Franc            |
| cJPY           | Celo Japanese Yen       | JPYm       | Mento Japanese Yen           |
| cNGN           | Celo Nigerian Naira     | NGNm       | Mento Nigerian Naira         |

### Transaction Details

This proposal consists of **60 transactions** (4 transactions per token × 15 tokens).

For each token, the renaming process follows four steps:

**Step 1: Switch to Temporary Implementation**

- Call `_setImplementation(address)` on the token proxy to switch from the current `StableTokenV2` implementation to the temporary `StableTokenV2Renamer` implementation. This temporary implementation exposes `setName` and `setSymbol` functions that allow updating the token name and symbol.

**Step 2: Update Name**

- Call `setName(string)` on the token (now using the renamer implementation) to update the name from the old format (e.g., `Celo Dollar`) to the new format (e.g., `Mento Dollar`).

**Step 3: Update Symbol**

- Call `setSymbol(string)` on the token to update the symbol from the old format (e.g., `cUSD`) to the new format (e.g., `USDm`).

**Step 4: Restore Original Implementation**

- Call `_setImplementation(address)` on the token proxy to switch back to the original `StableTokenV2` implementation, completing the rename process.

### Transaction Breakdown per Token

| TX# | Target      | Function                      | Parameters                        |
| --- | ----------- | ----------------------------- | --------------------------------- |
| 0   | Token Proxy | `_setImplementation(address)` | `StableTokenV2Renamer` address    |
| 1   | Token Proxy | `setName(string)`             | New name (e.g., `"Mento Dollar"`) |
| 2   | Token Proxy | `setSymbol(string)`           | New symbol (e.g., `"USDm"`)       |
| 3   | Token Proxy | `_setImplementation(address)` | `StableTokenV2` address           |

This pattern repeats for all 15 tokens.

**Relevant Addresses for Verification**

- StableTokenV2Renamer (temporary implementation)
  - https://celoscan.io/address/0x13450da8b43b198bf2d2650f788f943e34fb8a1b
- StableTokenV2 (original implementation)
  - https://celoscan.io/address/0x434563B0604BE100F04B7Ae485BcafE3c9D8850E

### Expected Outcome

Upon successful execution of this proposal:

1. All 15 Mento stablecoins will have their names and symbols updated to the new `XXXm` format
2. Token contract addresses remain unchanged — existing integrations continue to work
3. No changes to collateralization, minting mechanisms, or peg maintenance
4. Mento establishes a unified brand identity ready for multichain expansion
