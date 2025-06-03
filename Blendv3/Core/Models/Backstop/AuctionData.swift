//
//  AuctionData.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//
import Foundation

/// Auction for bad debt or liquidation
public struct AuctionData: Codable {
    
    /// Unique auction ID
    public let id: String
    
    /// Pool identifier
    public let poolId: String
    
    /// Type of auction
    public let auctionType: AuctionType
    
    /// Asset being auctioned
    public let assetAddress: String
    
    /// Amount of asset being auctioned
    public let assetAmount: Decimal
    
    /// Starting bid amount
    public let startingBid: Decimal
    
    /// Current highest bid
    public let currentBid: Decimal
    
    /// Current highest bidder
    public let currentBidder: String?
    
    /// Auction start timestamp
    public let startTime: Date
    
    /// Auction end timestamp
    public let endTime: Date
    
    /// Auction status
    public let status: AuctionStatus
    
    /// Minimum bid increment
    public let minBidIncrement: Decimal
    
    /// Reserve price (minimum acceptable bid)
    public let reservePrice: Decimal
    
    // MARK: - Calculated Properties
    
    /// Whether the auction is currently active
    public var isActive: Bool {
        let now = Date()
        return status == .active && now >= startTime && now < endTime
    }
    
    /// Whether the auction has ended
    public var hasEnded: Bool {
        return Date() >= endTime || status == .completed || status == .cancelled
    }
    
    /// Time remaining in auction (in seconds)
    public var timeRemaining: TimeInterval {
        return max(0, endTime.timeIntervalSince(Date()))
    }
    
    /// Whether reserve price has been met
    public var reserveMet: Bool {
        return currentBid >= reservePrice
    }
    
    /// Next minimum bid amount
    public var nextMinBid: Decimal {
        return currentBid + minBidIncrement
    }
    
    public init(
        id: String = UUID().uuidString,
        poolId: String,
        auctionType: AuctionType,
        assetAddress: String,
        assetAmount: Decimal,
        startingBid: Decimal,
        currentBid: Decimal? = nil,
        currentBidder: String? = nil,
        startTime: Date = Date(),
        duration: TimeInterval = 86400, // 24 hours default
        status: AuctionStatus = .active,
        minBidIncrement: Decimal,
        reservePrice: Decimal
    ) {
        self.id = id
        self.poolId = poolId
        self.auctionType = auctionType
        self.assetAddress = assetAddress
        self.assetAmount = assetAmount
        self.startingBid = startingBid
        self.currentBid = currentBid ?? startingBid
        self.currentBidder = currentBidder
        self.startTime = startTime
        self.endTime = startTime.addingTimeInterval(duration)
        self.status = status
        self.minBidIncrement = minBidIncrement
        self.reservePrice = reservePrice
        
        BlendLogger.info(
            "AuctionData created: \(id) for \(auctionType.rawValue), asset: \(assetAddress)",
            category: BlendLogger.rateCalculation
        )
    }
}


extension AuctionData: Equatable {
    public static func == (lhs: AuctionData, rhs: AuctionData) -> Bool {
        return lhs.id == rhs.id
    }
}
