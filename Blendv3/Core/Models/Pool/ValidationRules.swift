//
//  ValidationRules.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//
import Foundation

/// Rules for validating user input
public struct ValidationRules {
    let minValue: Decimal?
    let maxValue: Decimal?
    let required: Bool
    let customValidators: [(Any) throws -> Void]
    
    public static var depositAmount: ValidationRules {
        ValidationRules(
            minValue: Decimal(0.01), // Minimum 0.01 USDC
            maxValue: Decimal(1_000_000), // Maximum 1M USDC
            required: true,
            customValidators: []
        )
    }
    
    public static var withdrawAmount: ValidationRules {
        ValidationRules(
            minValue: Decimal(0.01), // Minimum 0.01 USDC
            maxValue: Decimal(1_000_000), // Maximum 1M USDC
            required: true,
            customValidators: []
        )
    }
    
    
}
