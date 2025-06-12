//
//  OracleModels.swift
//  Blendv3
//
//  Shared models for Oracle-related data structures
//

import Foundation

// MARK: - Historical Data Point
struct HistoricalDataPoint: Decodable, Equatable {
    let date: Date
    let price: Double
    let volume: Double
    let change: Double?
    
    enum CodingKeys: String, CodingKey {
        case date = "timestamp"
        case price
        case volume
        case change
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle date as timestamp
        let timestamp = try container.decode(Double.self, forKey: .date)
        self.date = Date(timeIntervalSince1970: timestamp)
        
        self.price = try container.decode(Double.self, forKey: .price)
        self.volume = try container.decode(Double.self, forKey: .volume)
        self.change = try container.decodeIfPresent(Double.self, forKey: .change)
    }
    
    init(date: Date, price: Double, volume: Double, change: Double?) {
        self.date = date
        self.price = price
        self.volume = volume
        self.change = change
    }
}