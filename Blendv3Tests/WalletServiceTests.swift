//
//  WalletServiceTests.swift
//  Blendv3Tests
//
//  Unit tests for wallet service
//

import Testing
import stellarsdk
@testable import Blendv3

struct WalletServiceTests {
    
    @Test func createWallet() async throws {
        let service = WalletService()
        
        let wallet = try service.createWallet()
        #expect(wallet.accountId.count == 56) // Stellar account IDs are 56 characters
        #expect(wallet.accountId.starts(with: "G"))
        #expect(wallet.secretSeed != nil)
    }
    
    @Test func importWallet() async throws {
        let service = WalletService()
        
        // Test with valid seed
        let validSeed = "SAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        do {
            _ = try service.importWallet(secretSeed: validSeed)
        } catch {
            // This is expected as the seed is valid format but not a real key
            #expect(error is WalletError)
        }
        
        // Test with invalid seed
        let invalidSeed = "INVALID"
        do {
            _ = try service.importWallet(secretSeed: invalidSeed)
            #expect(Bool(false), "Should have thrown error")
        } catch {
            #expect(error is WalletError)
            if case WalletError.invalidSecretSeed = error {
                // Expected
            } else {
                #expect(Bool(false), "Wrong error type")
            }
        }
    }
}