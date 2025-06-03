//
//  ReserveDataResult.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//
import Foundation

public struct ReserveDataResult: Codable {
    public let assetAddress: String
    public let totalSupplied: Decimal
    public let totalBorrowed: Decimal
    public let supplyAPY: Decimal
    public let borrowAPY: Decimal
    public let utilizationRate: Decimal
    public let scalar: Decimal
    
    public init(
        assetAddress: String = "",
        totalSupplied: Decimal,
        totalBorrowed: Decimal,
        supplyAPY: Decimal,
        borrowAPY: Decimal,
        utilizationRate: Decimal,
        scalar: Decimal = 1.0
    ) {
        self.assetAddress = assetAddress
        self.totalSupplied = totalSupplied
        self.totalBorrowed = totalBorrowed
        self.supplyAPY = supplyAPY
        self.borrowAPY = borrowAPY
        self.utilizationRate = utilizationRate
        self.scalar = scalar
    }
}
