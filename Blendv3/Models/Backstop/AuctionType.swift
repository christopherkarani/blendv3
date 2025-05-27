//
//  AuctionType.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//


// MARK: - Auction Type

public enum AuctionType: String, CaseIterable, Codable {
    case badDebt = "bad_debt"
    case liquidation = "liquidation"
    case interest = "interest"
    
    public var description: String {
        switch self {
        case .badDebt:
            return "Bad Debt Auction"
        case .liquidation:
            return "Liquidation Auction"
        case .interest:
            return "Interest Auction"
        }
    }
}