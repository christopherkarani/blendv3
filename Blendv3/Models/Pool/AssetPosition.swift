//
//  AssetPosition.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//

import Foundation

/// Asset position
public struct AssetPosition {
    public let assetId: String
    public let supplied: Decimal
    public let borrowed: Decimal
    public let collateral: Decimal
    public let availableToBorrow: Decimal
}
