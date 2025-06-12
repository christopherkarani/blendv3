//
//  WithdrawalStatus.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//


public enum WithdrawalStatus: String, CaseIterable, Codable {
    case queued = "queued"
    case executed = "executed"
    case cancelled = "cancelled"
    case expired = "expired"
    
    public var description: String {
        switch self {
        case .queued:
            return "Queued"
        case .executed:
            return "Executed"
        case .cancelled:
            return "Cancelled"
        case .expired:
            return "Expired"
        }
    }
}