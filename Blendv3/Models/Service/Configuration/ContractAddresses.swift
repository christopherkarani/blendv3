//
//  ContractAddresses.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - Contract Configuration

/// Contract addresses for different network environments
public struct ContractAddresses {
    public let poolAddress: String
    public let backstopAddress: String
    public let emissionsAddress: String
    public let usdcAddress: String
    
    public init(poolAddress: String, backstopAddress: String, emissionsAddress: String, usdcAddress: String) {
        self.poolAddress = poolAddress
        self.backstopAddress = backstopAddress
        self.emissionsAddress = emissionsAddress
        self.usdcAddress = usdcAddress
    }
}