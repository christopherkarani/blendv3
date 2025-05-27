//
//  AuctionStatus.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//


public enum AuctionStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"
    case failed = "failed"
    
    public var description: String {
        switch self {
        case .pending:
            return "Pending"
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        case .failed:
            return "Failed"
        }
    }
}