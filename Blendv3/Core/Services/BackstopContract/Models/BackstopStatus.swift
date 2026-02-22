//
//  BackstopStatus.swift
//  Blendv3
//
//  Created by Chris Karani on 27/05/2025.
//

public enum BackstopStatus: String, CaseIterable, Codable {
    case active = "active"
    case paused = "paused"
    case emergency = "emergency"
    case liquidation = "liquidation"
    
    public var description: String {
        switch self {
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        case .emergency:
            return "Emergency"
        case .liquidation:
            return "Liquidation"
        }
    }
    
    public var canDeposit: Bool {
        return self == .active
    }
    
    public var canWithdraw: Bool {
        return self == .active || self == .paused
    }
}
