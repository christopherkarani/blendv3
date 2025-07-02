# Blend Financial Calculator – FAQ

Below are concise answers to the three implementation-level questions that frequently cause confusion when porting the Blend maths between **TypeScript** and **Swift**.

---

## 1. How do we access or calculate the accrued interest rate (`dRate`)?

| Context | Meaning of `dRate` | Where it lives | How to read / derive |
|---------|-------------------|----------------|-----------------------|
| **On-chain** | Global *debt-index* for a reserve. It grows monotonically to track the amount of interest that has accrued on all **dTokens**. |   Stellar Soroban storage entry `d_rate` (fixed-point **scalar-9**). |  - Read directly from the contract’s storage.<br/>- Updated every `set_rates()` call using:<br/>  `dRate  +=  utilisation × currentIR × Δt / YEAR` *(all fixed-point)*. |
| **SDK / TypeScript** | `ReserveData.dRate: bigint` (already scaled by **SCALAR_9 = 1e9**). |  Populated by `PoolLoader` when it unmarshals the on-chain struct. |  No extra work; just use `reserve.dRate`. |
| **Swift** | `BlendAssetData.dRate: Decimal` (raw on-chain value, still **scalar-9**). |  Filled by your JSON / XDR parser. |  Convert to a float when needed via `FixedMath.toFloat(value, 9)`. |

> **Quick check** – right after loading: `FixedMath.toFloat(dRate, 9)` should be close to **1.0** for a freshly initialised pool.

---

## 2. Exact field mapping between TypeScript `ReserveData` and Swift `BlendAssetData`

| Reserve attribute | TypeScript (`reserve.ts`) | Swift (`BlendAssetData`) | Notes |
|-------------------|---------------------------|--------------------------|-------|
| Total underlying supplied | `bSupply` *(bigint, scalar-7)* | `totalSupplied` *(Decimal)* | "b" = **bTokens** in circulation. |
| Total debt tokens | `dSupply` *(bigint, scalar-7)* | `totalBorrowed` *(Decimal)* | Holds only *principal*, interest captured via `dRate`. |
| Debt index | `dRate` *(bigint, scalar-9)* | `dRate` *(Decimal)* | See Q-1. |
| Base rate | `rBase` *(bigint, scalar-7)* | `rBase` *(Decimal)* | Start of slope-1 of kinked model. |
| Slope-1 | `rOne` | `rOne` | Same scaling (scalar-7). |
| Slope-2 | `rTwo` | `rTwo` | "target → 95 %" slope. |
| Slope-3 | `rThree` | `rThree` | Emergency slope. |
| Target utilisation | `utilTarget` *(bigint, scalar-7)* | `utilTarget` *(Decimal)* | Fraction (0–1). |
| Interest-rate modifier | `interestRateModifier` *(bigint, scalar-7)* | `irModifier` *(Decimal)* | Multiplies the whole kinked curve. |
| Backstop share | **not in struct** – passed separately | Provided to every call as `backstopTakeRate` | Same **scalar-7**. |

Scaling constants:
- **SCALAR_7 = 10⁷**
- **SCALAR_9 = 10⁹**

Keep the scaling identical in both languages; never rely on magnitude heuristics.

---

## 3. Should `calculateKinkedInterestRate` return decimals (`0.08`) or percentages (`8.0`)?

Return the **decimal fraction** (`0.08` for 8 %).

Rationale:
1. The on-chain rates (`rBase`, `rOne`, …) are stored as fixed-point decimals (e.g. `0.08 × 1e7 = 800 000`). When you convert with `toFloat` you get **0.08**.
2. The SDK’s `calculateCurrentInterestRate` keeps everything in the same unit and ultimately feeds it to `convertAPRtoAPY`, which expects a **decimal** (not a percentage).
3. Returning percentages would require every consumer to divide by 100 again and invites double / missed conversions.

**Therefore keep the entire math pipeline in decimal terms and only multiply by 100 at the UI / formatting layer.**

---

> **Tip**: Add a unit test that calculates `currentIR`, `APR`, and `APY` for a known reserve snapshot in both Swift and TypeScript and assert that the values match within 1 × 10⁻⁶. This prevents silent scaling regressions.
