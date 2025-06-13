//
//  Position.swift
//  Blendv3
//
//  Created by Chris Karani on 14/06/2025.
//

import Foundation

/// Represents a user's position in the lending pool
public struct Position: Decodable {
    let asset: String
    let depositedAmount: Decimal
    let borrowedAmount: Decimal
    let collateralValue: Decimal
    let healthFactor: Decimal
    
    var isValid: Bool {
        // Check for NaN or infinite values is not directly available on Decimal, instead check if negative where not allowed
        // Negative values are invalid where not allowed
        // Assuming depositedAmount, collateralValue, healthFactor must be >= 0 (borrowedAmount can be 0 or more)
        
        if depositedAmount < 0 { return false }
        if borrowedAmount < 0 { return false }
        if collateralValue < 0 { return false }
        if healthFactor < 0 { return false }
        
        return true
    }
}
