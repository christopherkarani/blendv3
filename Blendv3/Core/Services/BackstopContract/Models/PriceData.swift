//
//  PriceData.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//
import Foundation
import stellarsdk

/// Price data structure that aligns with the smart contract's PriceData struct
public struct PriceData: Codable {
    public let price: Decimal
    public let timestamp: Date
    public let contractID: String
    public let baseAsset: String

    private enum CodingKeys: String, CodingKey {
        case price
        case timestamp
        case contractID = "asset"
        case decimals
        case baseAsset
    }

    public var priceInUSD: Decimal {
        return price
    }

    public init(price: Decimal, timestamp: Date, contractID: String, baseAsset: String) {
        self.price = price
        self.timestamp = timestamp
        self.contractID = contractID
        self.baseAsset = baseAsset
    }

    public init(price: Decimal, timestamp: Date, assetId: String) {
        self.price = price
        self.timestamp = timestamp
        self.contractID = assetId
        baseAsset = try! StellarContractID.toStrKey(contractID)
    }

    public func isStale(maxAge: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) > maxAge
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        price = try container.decode(Decimal.self, forKey: .price)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        contractID = try container.decode(String.self, forKey: .contractID)
        baseAsset = try container.decode(String.self, forKey: .baseAsset)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(price, forKey: .price)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(contractID, forKey: .contractID)
        try container.encode(baseAsset, forKey: .baseAsset)
    }
}
