# Blend Vault Swift App Alignment Plan

## Objective
Align the Swift Blend vault UI and logic with the Blend UI/SDK, ensuring accurate and user-friendly display of APR/APY, supply/borrow rates, and pool stats, following modern Swift, MVVM, and Combine best practices.

---

## Step 1: Research & Analysis
- **Review Blend UI and SDK:**
  - Study how APR, APY, supply/borrow rates, and pool stats are calculated and displayed in Blend UI and SDK (TypeScript/React).
  - Identify contract methods and data fields used for these stats (e.g., PoolEstimate, PositionsEstimate, supplyApr, borrowApr, etc.).
  - Note terminology changes (e.g., APY → APR) and ensure consistency.

**Rationale:**
Accurate mapping ensures the Swift app is a true source of truth and matches user expectations.

---

## Step 2: Define Data Models
- **Update/Create Swift Data Models:**
  - Mirror Blend's PoolEstimate and PositionsEstimate in Swift as structs.
  - Include fields: supplyApr, supplyApy, borrowApr, borrowApy, netApr, netApy, etc.
  - Use protocols for extensibility and testability.

**Rationale:**
Value types and protocol-oriented models improve safety, clarity, and testability.

---

## Step 3: Service Layer Updates
- **Update Vault Service:**
  - Fetch all required stats from the contract using correct method names and argument types.
  - Handle scaling/decimals as per contract and SDK conventions.
  - Add robust error handling and logging.

**Rationale:**
Ensures data accuracy and reliability for the ViewModel and UI.

---

## Step 4: ViewModel Updates
- **Expose All Relevant Stats:**
  - Use Combine publishers to expose APR, APY, supply/borrow rates, and net rates.
  - Ensure state is updated reactively and efficiently.

**Rationale:**
MVVM and Combine provide a clean, testable, and reactive data flow.

---

## Step 5: UI Updates
- **Update SwiftUI Views:**
  - Display stats in a way that matches Blend UI (APR, APY, supply/borrow, net rates).
  - Use correct terminology and formatting (e.g., percent style, correct decimal places).
  - Ensure accessibility and visual clarity.

**Rationale:**
Consistent UI/UX builds user trust and matches Blend's design language.

---

## Step 6: Testing & Validation
- **Add Unit Tests:**
  - Test calculation and formatting logic for APR/APY and other stats.
  - Compare displayed values with Blend UI for the same pool.

**Rationale:**
Testing ensures correctness and prevents regressions.

---

## Step 7: Documentation
- **Document Architecture & Logic:**
  - Explain data flow, key models, and any non-obvious logic.
  - Add code comments and update README as needed.

**Rationale:**
Good documentation aids maintainability and onboarding.

---

## Next Steps
- Proceed step by step, updating models, services, ViewModel, and UI.
- Validate each step with tests and UI comparison.
- Refine based on feedback and Blend protocol updates. 