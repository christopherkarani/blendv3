//
//  BackstopContractService.swift
//  Blendv3
//
//  Created by Chris Karani on 22/05/2025.
//

import Foundation
import Combine

// MARK: - Backstop Service Errors
enum BackstopServiceError: Error, LocalizedError {
    case invalidContractAddress
    case contractNotFound
    case insufficientBalance
    case operationFailed(String)
    case parsingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidContractAddress:
            return "Invalid backstop contract address"
        case .contractNotFound:
            return "Backstop contract not found"
        case .insufficientBalance:
            return "Insufficient balance for operation"
        case .operationFailed(let message):
            return "Backstop operation failed: \(message)"
        case .parsingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Backstop Contract Configuration
struct BackstopContractConfig {
    let contractId: String
    let networkConfiguration: NetworkConfiguration
    
    static let testnet = BackstopContractConfig(
        contractId: "BACKSTOP_CONTRACT_ID_TESTNET",
        networkConfiguration: .testnet
    )
    
    static let mainnet = BackstopContractConfig(
        contractId: "BACKSTOP_CONTRACT_ID_MAINNET",
        networkConfiguration: .mainnet
    )
}

// MARK: - Backstop Operations
enum BackstopOperation: String {
    case deposit = "deposit"
    case withdraw = "withdraw"
    case queueWithdrawal = "queue_withdrawal"
    case dequeueWithdrawal = "dequeue_withdrawal"
    case getBalance = "get_balance"
    case getWithdrawalQueue = "get_withdrawal_queue"
    case getTotalShares = "get_total_shares"
    case getRewards = "get_rewards"
    case claimRewards = "claim_rewards"
}

// MARK: - Backstop Data Models
struct BackstopBalance {
    let userAddress: String
    let shares: UInt64
    let underlyingBalance: UInt64
    let pendingRewards: UInt64
}

struct WithdrawalRequest {
    let userAddress: String
    let shares: UInt64
    let queuedAt: UInt64
    let availableAt: UInt64
}

struct BackstopStats {
    let totalShares: UInt64
    let totalAssets: UInt64
    let totalRewards: UInt64
    let sharePrice: Double
}

// MARK: - Backstop Contract Service Protocol
protocol BackstopContractServiceProtocol {
    func deposit(userAddress: String, amount: UInt64) async throws -> ContractResponse
    func withdraw(userAddress: String, shares: UInt64) async throws -> ContractResponse
    func queueWithdrawal(userAddress: String, shares: UInt64) async throws -> ContractResponse
    func dequeueWithdrawal(userAddress: String, requestId: String) async throws -> ContractResponse
    func getBalance(userAddress: String) async throws -> BackstopBalance
    func getWithdrawalQueue(userAddress: String) async throws -> [WithdrawalRequest]
    func getTotalShares() async throws -> UInt64
    func getBackstopStats() async throws -> BackstopStats
    func claimRewards(userAddress: String) async throws -> ContractResponse
}

// MARK: - Backstop Contract Service Implementation
@MainActor
final class BackstopContractService: BackstopContractServiceProtocol, ObservableObject {
    
    // MARK: - Properties
    private let networkService: NetworkService
    private let parser: BlendParser
    private let config: BackstopContractConfig
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var lastError: Error?
    
    // MARK: - Initialization
    init(
        networkService: NetworkService? = nil,
        config: BackstopContractConfig = .testnet
    ) {
        self.networkService = networkService ?? NetworkService(configuration: config.networkConfiguration)
        self.parser = BlendParser()
        self.config = config
    }
    
    // MARK: - Deposit Operations
    func deposit(userAddress: String, amount: UInt64) async throws -> ContractResponse {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let parameters: [Any] = [
                ["type": "SCV_ADDRESS", "value": userAddress],
                ["type": "SCV_U64", "value": amount]
            ]
            
            let operation = ContractOperation.invoke(
                contractId: config.contractId,
                method: BackstopOperation.deposit.rawValue,
                parameters: parameters
            )
            
            let responseData = try await networkService.performContractOperation(operation)
            let contractResponse = try parser.parseContractResponse(from: responseData)
            
            return contractResponse
            
        } catch {
            lastError = error
            if error is BackstopServiceError {
                throw error
            } else {
                throw BackstopServiceError.operationFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Withdrawal Operations
    func withdraw(userAddress: String, shares: UInt64) async throws -> ContractResponse {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let parameters: [Any] = [
                ["type": "SCV_ADDRESS", "value": userAddress],
                ["type": "SCV_U64", "value": shares]
            ]
            
            let operation = ContractOperation.invoke(
                contractId: config.contractId,
                method: BackstopOperation.withdraw.rawValue,
                parameters: parameters
            )
            
            let responseData = try await networkService.performContractOperation(operation)
            let contractResponse = try parser.parseContractResponse(from: responseData)
            
            return contractResponse
            
        } catch {
            lastError = error
            if error is BackstopServiceError {
                throw error
            } else {
                throw BackstopServiceError.operationFailed(error.localizedDescription)
            }
        }
    }
    
    func queueWithdrawal(userAddress: String, shares: UInt64) async throws -> ContractResponse {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let parameters: [Any] = [
                ["type": "SCV_ADDRESS", "value": userAddress],
                ["type": "SCV_U64", "value": shares]
            ]
            
            let operation = ContractOperation.invoke(
                contractId: config.contractId,
                method: BackstopOperation.queueWithdrawal.rawValue,
                parameters: parameters
            )
            
            let responseData = try await networkService.performContractOperation(operation)
            let contractResponse = try parser.parseContractResponse(from: responseData)
            
            return contractResponse
            
        } catch {
            lastError = error
            if error is BackstopServiceError {
                throw error
            } else {
                throw BackstopServiceError.operationFailed(error.localizedDescription)
            }
        }
    }
    
    func dequeueWithdrawal(userAddress: String, requestId: String) async throws -> ContractResponse {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let parameters: [Any] = [
                ["type": "SCV_ADDRESS", "value": userAddress],
                ["type": "SCV_STRING", "value": requestId]
            ]
            
            let operation = ContractOperation.invoke(
                contractId: config.contractId,
                method: BackstopOperation.dequeueWithdrawal.rawValue,
                parameters: parameters
            )
            
            let responseData = try await networkService.performContractOperation(operation)
            let contractResponse = try parser.parseContractResponse(from: responseData)
            
            return contractResponse
            
        } catch {
            lastError = error
            if error is BackstopServiceError {
                throw error
            } else {
                throw BackstopServiceError.operationFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Query Operations
    func getBalance(userAddress: String) async throws -> BackstopBalance {
        do {
            let parameters: [Any] = [
                ["type": "SCV_ADDRESS", "value": userAddress]
            ]
            
            let operation = ContractOperation.query(
                contractId: config.contractId,
                method: BackstopOperation.getBalance.rawValue,
                parameters: parameters
            )
            
            let responseData = try await networkService.performContractOperation(operation)
            let contractResponse = try parser.parseContractResponse(from: responseData)
            
            return try parseBackstopBalance(from: contractResponse, userAddress: userAddress)
            
        } catch {
            lastError = error
            if error is BackstopServiceError {
                throw error
            } else {
                throw BackstopServiceError.parsingFailed(error)
            }
        }
    }
    
    func getWithdrawalQueue(userAddress: String) async throws -> [WithdrawalRequest] {
        do {
            let parameters: [Any] = [
                ["type": "SCV_ADDRESS", "value": userAddress]
            ]
            
            let operation = ContractOperation.query(
                contractId: config.contractId,
                method: BackstopOperation.getWithdrawalQueue.rawValue,
                parameters: parameters
            )
            
            let responseData = try await networkService.performContractOperation(operation)
            let contractResponse = try parser.parseContractResponse(from: responseData)
            
            return try parseWithdrawalQueue(from: contractResponse, userAddress: userAddress)
            
        } catch {
            lastError = error
            if error is BackstopServiceError {
                throw error
            } else {
                throw BackstopServiceError.parsingFailed(error)
            }
        }
    }
    
    func getTotalShares() async throws -> UInt64 {
        do {
            let operation = ContractOperation.query(
                contractId: config.contractId,
                method: BackstopOperation.getTotalShares.rawValue,
                parameters: []
            )
            
            let responseData = try await networkService.performContractOperation(operation)
            let contractResponse = try parser.parseContractResponse(from: responseData)
            
            guard let result = contractResponse.result,
                  let totalShares = result.value as? UInt64 else {
                throw BackstopServiceError.parsingFailed(ParsingError.invalidFormat("Expected UInt64 for total shares"))
            }
            
            return totalShares
            
        } catch {
            lastError = error
            if error is BackstopServiceError {
                throw error
            } else {
                throw BackstopServiceError.parsingFailed(error)
            }
        }
    }
    
    func getBackstopStats() async throws -> BackstopStats {
        // This would typically be implemented with multiple contract calls
        // For now, we'll create a consolidated stats query
        async let totalShares = getTotalShares()
        
        do {
            let shares = try await totalShares
            
            // In a real implementation, you would make additional calls to get:
            // - Total assets under management
            // - Total pending rewards
            // - Current share price
            
            return BackstopStats(
                totalShares: shares,
                totalAssets: 0, // Would be fetched from contract
                totalRewards: 0, // Would be fetched from contract
                sharePrice: 1.0 // Would be calculated from contract data
            )
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    func claimRewards(userAddress: String) async throws -> ContractResponse {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let parameters: [Any] = [
                ["type": "SCV_ADDRESS", "value": userAddress]
            ]
            
            let operation = ContractOperation.invoke(
                contractId: config.contractId,
                method: BackstopOperation.claimRewards.rawValue,
                parameters: parameters
            )
            
            let responseData = try await networkService.performContractOperation(operation)
            let contractResponse = try parser.parseContractResponse(from: responseData)
            
            return contractResponse
            
        } catch {
            lastError = error
            if error is BackstopServiceError {
                throw error
            } else {
                throw BackstopServiceError.operationFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Private Parsing Helpers
    private func parseBackstopBalance(from response: ContractResponse, userAddress: String) throws -> BackstopBalance {
        guard let result = response.result else {
            throw BackstopServiceError.parsingFailed(ParsingError.missingRequiredField("result"))
        }
        
        // Assuming the result is a map with balance information
        guard let balanceData = try parser.convertSCValToSwift(result) as? [String: Any] else {
            throw BackstopServiceError.parsingFailed(ParsingError.invalidFormat("Expected map for balance data"))
        }
        
        let shares = balanceData["shares"] as? UInt64 ?? 0
        let underlyingBalance = balanceData["underlying_balance"] as? UInt64 ?? 0
        let pendingRewards = balanceData["pending_rewards"] as? UInt64 ?? 0
        
        return BackstopBalance(
            userAddress: userAddress,
            shares: shares,
            underlyingBalance: underlyingBalance,
            pendingRewards: pendingRewards
        )
    }
    
    private func parseWithdrawalQueue(from response: ContractResponse, userAddress: String) throws -> [WithdrawalRequest] {
        guard let result = response.result else {
            return [] // Empty queue
        }
        
        guard let queueArray = try parser.convertSCValToSwift(result) as? [Any] else {
            throw BackstopServiceError.parsingFailed(ParsingError.invalidFormat("Expected array for withdrawal queue"))
        }
        
        return try queueArray.compactMap { item in
            guard let requestData = item as? [String: Any] else { return nil }
            
            let shares = requestData["shares"] as? UInt64 ?? 0
            let queuedAt = requestData["queued_at"] as? UInt64 ?? 0
            let availableAt = requestData["available_at"] as? UInt64 ?? 0
            
            return WithdrawalRequest(
                userAddress: userAddress,
                shares: shares,
                queuedAt: queuedAt,
                availableAt: availableAt
            )
        }
    }
}

// MARK: - Convenience Extensions
extension BackstopBalance: CustomStringConvertible {
    var description: String {
        return "BackstopBalance(user: \(userAddress), shares: \(shares), balance: \(underlyingBalance), rewards: \(pendingRewards))"
    }
}

extension WithdrawalRequest: CustomStringConvertible {
    var description: String {
        return "WithdrawalRequest(user: \(userAddress), shares: \(shares), queued: \(queuedAt), available: \(availableAt))"
    }
}

extension BackstopStats: CustomStringConvertible {
    var description: String {
        return "BackstopStats(totalShares: \(totalShares), totalAssets: \(totalAssets), price: \(sharePrice))"
    }
}