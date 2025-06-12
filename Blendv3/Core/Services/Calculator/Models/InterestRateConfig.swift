//
//  InterestRateConfig.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//
import Foundation

/// Interest rate configuration for three-slope model
public struct InterestRateConfig {
    /// Target utilization ratio (0-1)
    public let targetUtilization: Decimal
    
    /// Base interest rate (fixed-point with 7 decimals)
    public let rBase: Decimal
    
    /// First slope rate (fixed-point with 7 decimals)
    public let rOne: Decimal
    
    /// Second slope rate (fixed-point with 7 decimals)
    public let rTwo: Decimal
    
    /// Third slope rate (fixed-point with 7 decimals)
    public let rThree: Decimal
    
    /// Reactivity parameter for rate modifier
    public let reactivity: Decimal
    
    /// Current interest rate modifier
    public let interestRateModifier: Decimal
    
    public init(
        targetUtilization: Decimal,
        rBase: Decimal,
        rOne: Decimal,
        rTwo: Decimal,
        rThree: Decimal,
        reactivity: Decimal,
        interestRateModifier: Decimal = FixedMath.SCALAR_7
    ) {
        self.targetUtilization = targetUtilization
        self.rBase = rBase
        self.rOne = rOne
        self.rTwo = rTwo
        self.rThree = rThree
        self.reactivity = reactivity
        self.interestRateModifier = interestRateModifier
    }
} 
