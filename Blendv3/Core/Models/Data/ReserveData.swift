//
//  ReserveData.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Data Transformation Models

/// Generic reserve data model for data transformation
public struct ReserveData {
    public let totalSupplied: Decimal
    public let totalBorrowed: Decimal
    public let supplyRate: Decimal
    public let borrowRate: Decimal
    public let utilizationRate: Decimal
    public let lastUpdateTime: Date
    
    public init(totalSupplied: Decimal, totalBorrowed: Decimal, supplyRate: Decimal, borrowRate: Decimal, utilizationRate: Decimal, lastUpdateTime: Date) {
        self.totalSupplied = totalSupplied
        self.totalBorrowed = totalBorrowed
        self.supplyRate = supplyRate
        self.borrowRate = borrowRate
        self.utilizationRate = utilizationRate
        self.lastUpdateTime = lastUpdateTime
    }
}