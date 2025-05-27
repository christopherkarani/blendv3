//
//  BackstopPoolReserveData.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//
import Foundation

/// Pool reserve data for backstop calculations
public struct BackstopPoolReserveData {
    public let assetId: String
    public let totalBorrowed: Decimal
    public let borrowAPR: Decimal
    public let assetDecimals: Int
    
    public func totalBorrowedUSD(priceData: PriceData) -> Double {
        let assetPrice = FixedMath.toFloat(value: priceData.price, decimals: 7)
        let borrowedAmount = FixedMath.toFloat(value: totalBorrowed, decimals: assetDecimals)
        let result = borrowedAmount * assetPrice
        return NSDecimalNumber(decimal: result).doubleValue
    }
    
    public init(assetId: String, totalBorrowed: Decimal, borrowAPR: Decimal, assetDecimals: Int = 7) {
        self.assetId = assetId
        self.totalBorrowed = totalBorrowed
        self.borrowAPR = borrowAPR
        self.assetDecimals = assetDecimals
    }
}
