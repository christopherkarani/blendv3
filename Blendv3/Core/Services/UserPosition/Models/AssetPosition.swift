//
//  AssetPosition.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//

import Foundation

/// Asset position
public struct AssetPosition: Sendable, Equatable {
    public let assetId: String
    public let supplied: Decimal
    public let borrowed: Decimal
    public let collateral: Decimal
    public let availableToBorrow: Decimal
    
    // MARK: - Initialization
    
    public init(assetId: String, supplied: Decimal, borrowed: Decimal, collateral: Decimal, availableToBorrow: Decimal) {
        self.assetId = assetId
        self.supplied = supplied
        self.borrowed = borrowed
        self.collateral = collateral
        self.availableToBorrow = availableToBorrow
    }
}

// MARK: - Codable Conformance

extension AssetPosition: Codable {
    private enum CodingKeys: String, CodingKey {
        case assetId
        case supplied
        case borrowed
        case collateral
        case availableToBorrow
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        assetId = try container.decode(String.self, forKey: .assetId)
        
        // Decode Decimal values safely using String intermediary
        let suppliedString = try container.decode(String.self, forKey: .supplied)
        supplied = Decimal(string: suppliedString) ?? .zero
        
        let borrowedString = try container.decode(String.self, forKey: .borrowed)
        borrowed = Decimal(string: borrowedString) ?? .zero
        
        let collateralString = try container.decode(String.self, forKey: .collateral)
        collateral = Decimal(string: collateralString) ?? .zero
        
        let availableToBorrowString = try container.decode(String.self, forKey: .availableToBorrow)
        availableToBorrow = Decimal(string: availableToBorrowString) ?? .zero
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(assetId, forKey: .assetId)
        
        // Encode Decimal values as strings for reliable serialization
        try container.encode(supplied.description, forKey: .supplied)
        try container.encode(borrowed.description, forKey: .borrowed)
        try container.encode(collateral.description, forKey: .collateral)
        try container.encode(availableToBorrow.description, forKey: .availableToBorrow)
    }
}
