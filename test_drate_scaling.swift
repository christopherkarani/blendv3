#!/usr/bin/env swift

import Foundation

let dRateRaw = Decimal(1002041703659)
let SCALAR_7 = Decimal(10_000_000)
let SCALAR_9 = Decimal(1_000_000_000)

print("🔍 Testing dRate Scaling")
print("========================")
print("Raw dRate: \(dRateRaw)")

print("\nTesting different scalings:")
print("1. SCALAR_7 (1e7): \(dRateRaw / SCALAR_7)")
print("2. SCALAR_9 (1e9): \(dRateRaw / SCALAR_9)")
print("3. No scaling: \(dRateRaw)")

print("\nExpected dRate should be close to 1.0 for a fresh pool")
print("or slightly above 1.0 for a pool with accrued interest")

// Test which scaling gives us a reasonable dRate (close to 1.0)
let scaledBy7 = dRateRaw / SCALAR_7
let scaledBy9 = dRateRaw / SCALAR_9

print("\nAnalysis:")
if scaledBy7 >= 1.0 && scaledBy7 <= 2.0 {
    print("✅ SCALAR_7 gives reasonable result: \(scaledBy7)")
} else {
    print("❌ SCALAR_7 gives unreasonable result: \(scaledBy7)")
}

if scaledBy9 >= 1.0 && scaledBy9 <= 2.0 {
    print("✅ SCALAR_9 gives reasonable result: \(scaledBy9)")
} else {
    print("❌ SCALAR_9 gives unreasonable result: \(scaledBy9)")
}

// Based on the TypeScript reference, dRate should be close to 1.0
// Let's see what scaling factor would give us ~1.002
let targetDRate = Decimal(1.002)
let impliedScaling = dRateRaw / targetDRate
print("\nTo get dRate ≈ 1.002, we'd need scaling factor: \(impliedScaling)")
print("This is closest to: \(impliedScaling / SCALAR_9) * 1e9") 