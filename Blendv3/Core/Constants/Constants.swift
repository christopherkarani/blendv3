//
//  Constants.swift
//  Blendv3
//
//  Global constants for the application
//

import Foundation

enum Constants {
    enum Network {
        static let testnet = "https://horizon-testnet.stellar.org"
        static let testnetSorobanRPC = "https://soroban-testnet.stellar.org"
        static let mainnet = "https://horizon.stellar.org"
        static let mainnetSorobanRPC = "https://soroban-rpc.mainnet.stellar.gateway.fm"
        
        static let testnetPassphrase = "Test SDF Network ; September 2015"
        static let mainnetPassphrase = "Public Global Stellar Network ; September 2015"
    }
    
    enum Keychain {
        static let serviceName = "com.beebop.blendv3"
        static let activeWalletKey = "activeWalletIdentifier"
    }
    
    enum Blend {
        // Testnet contract addresses (to be updated with actual addresses)
        static let emitterContractId = "CCREATE2SPDXC4QBHQD2K33HBQJYQQ53ZWDPZGDISBEYR2V6HQN27QXN"
        static let backstopContractId = "CBAQZGQBHAWLR7M2WZH4B2TRNQIX4ZQUQQOCQVJNCRVUBMRZLRPPQ3AP"
        static let poolFactoryContractId = "CAAJY3BXRFC3V3VPP3VGMJQM3MWNQPUQTAWNA6MEGUMUZFBQYM5EW2BG"
        
        // Common function names
        static let supplyFunction = "supply"
        static let withdrawFunction = "withdraw"
        static let borrowFunction = "borrow"
        static let repayFunction = "repay"
    }
    
    enum UI {
        static let animationDuration = 0.3
        static let cornerRadius = 12.0
        static let shadowRadius = 8.0
    }
}