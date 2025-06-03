//
//  MethodOptions.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Contract Interaction Models

/// Options for Soroban contract method invocation
public struct MethodOptions {
    public let fee: UInt32
    public let timeoutInSeconds: UInt32
    public let simulate: Bool
    public let restore: Bool
    
    public init(fee: UInt32 = 100_000, timeoutInSeconds: UInt32 = 30, simulate: Bool = true, restore: Bool = false) {
        self.fee = fee
        self.timeoutInSeconds = timeoutInSeconds
        self.simulate = simulate
        self.restore = restore
    }
}