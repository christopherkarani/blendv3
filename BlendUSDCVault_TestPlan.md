# Test Plan: BlendUSDCVault.swift

This document outlines the step-by-step plan for creating a comprehensive test suite for `BlendUSDCVault.swift`.

## Phase 1: Enhance Testability (Refactoring `BlendUSDCVault`)

*   **Step 1.1: Dependency Injection for `SorobanServer`.** Modify `BlendUSDCVault`'s initializer to accept an instance of `SorobanServer` instead of creating it internally based on `NetworkType`. This is crucial for mocking network interactions effectively. The `NetworkType` can still be a parameter to inform logic if needed, but the server instance itself should be injectable.
    *   *Rationale:* Direct control over `SorobanServer` in tests allows us to simulate various network responses and error conditions without actual network calls, making tests fast, reliable, and deterministic.

## Phase 2: Test Infrastructure Setup

*   **Step 2.1: Create `BlendUSDCVaultTests.swift`.** Add a new XCTestCase file to the `Blendv3Tests` target.
*   **Step 2.2: Create Mock Objects.**
    *   `MockBlendSigner`: Implement a mock conforming to the `BlendSigner` protocol (assuming `BlendSigner` is a protocol or a class that can be subclassed/mocked). This mock should allow setting a dummy public key and controlling the behavior of its `sign` method (e.g., return a predefined signature or throw an error).
    *   `MockSorobanServer`: Create a mock for `SorobanServer`. This mock will need methods to stub responses for `getLatestLedger`, `prepareTransaction`, `sendTransaction`, `getTransaction`, and `invokeMethod` (or whichever methods `BlendUSDCVault` directly uses from `SorobanServer` or its internally created `SorobanClient`).
    *   `MockSorobanClient` (Optional but likely needed): If `BlendUSDCVault`'s `initializeSorobanClient` method directly creates and uses a `SorobanClient` instance for certain operations (like `invokeMethod` for `refreshPoolStats`), we'll need a way to inject a mock `SorobanClient` or ensure the internally created one uses our `MockSorobanServer`. The ideal refactor in Phase 1 would also make `SorobanClient` injectable or provide a factory.
*   **Step 2.3: `setUpWithError` and `tearDownWithError`.** In `BlendUSDCVaultTests.swift`, implement these methods to initialize the `sut` (System Under Test - our `BlendUSDCVault` instance) with its mocked dependencies before each test and clean up afterwards.

## Phase 3: Testing Initialization (`init` and `initializeSorobanClient`)

*   **Step 3.1: Test `init` with different `NetworkType`s.** Verify that the `signer` and `networkType` are correctly stored. If `SorobanServer` is injected (from Phase 1), this test simplifies to checking property assignment.
*   **Step 3.2: Test `initializeSorobanClient` success.**
    *   Mock `sorobanServer.getLatestLedger` and `sorobanServer.prepareTransaction` to return successful responses.
    *   Verify that `sorobanClient` is set up correctly.
    *   Verify `isLoading` is handled and no `error` is published.
*   **Step 3.3: Test `initializeSorobanClient` failure paths.**
    *   Simulate errors from `sorobanServer` methods.
    *   Verify `self.error` is set to an appropriate `BlendVaultError`.

## Phase 4: Testing Core Functionality (`deposit`, `withdraw`)

*   **Step 4.1: Test `deposit(amount:)` - Successful Path.**
    *   Input: Valid positive `amount`.
    *   Mocks: `MockBlendSigner` returns valid signature, `MockSorobanServer` simulates successful transaction.
    *   Assertions: Correct transaction hash, `isLoading` toggles, `error` is `nil`, `refreshPoolStats` triggered.
*   **Step 4.2: Test `deposit(amount:)` - Invalid Amount.**
    *   Input: `amount = 0`, `amount < 0`.
    *   Assertions: `BlendVaultError.invalidAmount` thrown, no network calls.
*   **Step 4.3: Test `deposit(amount:)` - Network/Signing Failure Paths.**
    *   Simulate errors from `signer.sign`, `sorobanServer.prepareTransaction`, `sendTransaction`, `getTransaction`.
    *   Assertions: Appropriate `BlendVaultError` published, `isLoading` resets, `error` property set.
*   **Step 4.4: Test `withdraw(amount:)` - Apply similar test cases as `deposit`** (successful, invalid amount, failures).

## Phase 5: Testing Pool Statistics (`refreshPoolStats`)

*   **Step 5.1: Test `refreshPoolStats()` - Successful Path.**
    *   Mocks: `MockSorobanServer` returns valid `SCValXDR` for `get_reserve`.
    *   Assertions: `isLoading` toggles, `error` is `nil`, `poolStats` updated correctly.
*   **Step 5.2: Test `refreshPoolStats()` - `SorobanClient` Not Initialized.**
    *   Assertions: `BlendVaultError.notInitialized` thrown/published.
*   **Step 5.3: Test `refreshPoolStats()` - Network Failure.**
    *   Simulate `invokeMethod` throwing an error.
    *   Assertions: Appropriate `BlendVaultError` published, `isLoading` resets, `error` set.
*   **Step 5.4: Test `refreshPoolStats()` - Malformed/Incomplete Data.**
    *   Mock `invokeMethod` to return incomplete/malformed `SCValXDR`.
    *   Assertions: Verify graceful handling (e.g., `nil` for affected stats).

## Phase 6: Testing Private Helpers and State Management

*   **Step 6.1: Test `convertRateToAPY(_:)`.**
    *   Preferably make `internal` for direct testing. Test with zero, positive, and edge-case rates.
*   **Step 6.2: Test `createRequest(type:amount:)` (Indirectly).**
    *   Verify through `deposit`/`withdraw` by inspecting arguments passed to mocked `submitTransaction`.
*   **Step 6.3: Test `submitTransaction(requests:)` (Indirectly).**
    *   Covered by failure path tests in `deposit`/`withdraw`.
*   **Step 6.4: Comprehensive State Testing (`isLoading`, `error`, `poolStats`).**
    *   Consistently verify `@Published` properties using Combine testing utilities or `XCTestExpectation`.

## Phase 7: Review, Refine, and Iterate

*   **Step 7.1: Code Coverage Analysis.** Identify untested lines/branches.
*   **Step 7.2: Add Missing Tests.** Based on coverage and insights.
*   **Step 7.3: Refactor Tests.** For clarity and maintainability.
