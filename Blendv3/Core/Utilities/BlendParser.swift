//
//  BlendParser.swift
//  Blendv3
//
//  Created by Chris Karani on 30/05/2025.
//

import Foundation
import stellarsdk

struct BlendParser {
    // Helper to convert Int128PartsXDR to Decimal
    static  func parseI128ToDecimal(_ value: Int128PartsXDR) -> Decimal {
        // Convert i128 to a single 128-bit integer value
        let fullValue: Decimal
        if value.hi == 0 {
            // Simple case: only low 64 bits are used
            fullValue = Decimal(value.lo)
        } else if value.hi == -1 && (value.lo & 0x8000000000000000) != 0 {
            // Negative number in two's complement
            let signedLo = Int64(bitPattern: value.lo)
            fullValue = Decimal(signedLo)
        } else {
            // Large positive number: combine hi and lo parts
            // hi represents the upper 64 bits, lo represents the lower 64 bits
            let hiDecimal = Decimal(value.hi) * Decimal(sign: .plus, exponent: 64, significand: 1)
            let loDecimal = Decimal(value.lo)
            fullValue = hiDecimal + loDecimal
        }
        // The value from the oracle is in fixed-point format with 7 decimals
        // So we need to return the raw value as-is (it's already scaled)
        return fullValue
    }
}
