import Foundation
import Combine

// MARK: - Pool Service Protocol
protocol PoolServiceProtocol {
    // Pool Information
    func getPoolData(contractId: String) -> AnyPublisher<PoolData, PoolError>
    func getPoolReserves(contractId: String) -> AnyPublisher<[ReserveData], PoolError>
    func getPoolStatus(contractId: String) -> AnyPublisher<PoolStatus, PoolError>
    
    // Supply Operations
    func supply(contractId: String, asset: String, amount: Decimal, onBehalfOf: String?) -> AnyPublisher<SupplyResult, PoolError>
    func withdraw(contractId: String, asset: String, amount: Decimal, to: String?) -> AnyPublisher<WithdrawResult, PoolError>
    
    // Borrow Operations
    func borrow(contractId: String, asset: String, amount: Decimal) -> AnyPublisher<BorrowResult, PoolError>
    func repay(contractId: String, asset: String, amount: Decimal, onBehalfOf: String?) -> AnyPublisher<RepayResult, PoolError>
    
    // Liquidation
    func liquidate(contractId: String, user: String, debtAsset: String, collateralAsset: String, amount: Decimal) -> AnyPublisher<LiquidationResult, PoolError>
    
    // Pool Configuration
    func getReserveConfiguration(contractId: String, asset: String) -> AnyPublisher<ReserveConfiguration, PoolError>
    func getPoolConfiguration(contractId: String) -> AnyPublisher<PoolConfiguration, PoolError>
}

// MARK: - Pool Error
enum PoolError: LocalizedError {
    case networkError(NetworkError)
    case parsingError(ParsingError)
    case insufficientBalance
    case reserveNotFound(String)
    case poolPaused
    case poolFrozen
    case borrowingDisabled
    case healthFactorTooLow
    case invalidAmount
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Pool network error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Pool parsing error: \(error.localizedDescription)"
        case .insufficientBalance:
            return "Insufficient balance"
        case .reserveNotFound(let asset):
            return "Reserve not found for asset: \(asset)"
        case .poolPaused:
            return "Pool is paused"
        case .poolFrozen:
            return "Pool is frozen"
        case .borrowingDisabled:
            return "Borrowing is disabled for this reserve"
        case .healthFactorTooLow:
            return "Health factor too low"
        case .invalidAmount:
            return "Invalid amount"
        case .unauthorized:
            return "Unauthorized operation"
        }
    }
}

// MARK: - Result Types
struct SupplyResult {
    let shares: Decimal
    let suppliedAmount: Decimal
    let newTotalSupply: Decimal
    let transactionHash: String?
}

struct WithdrawResult {
    let withdrawnAmount: Decimal
    let sharesBurned: Decimal
    let remainingSupply: Decimal
    let transactionHash: String?
}

struct BorrowResult {
    let borrowedAmount: Decimal
    let newTotalBorrowed: Decimal
    let newHealthFactor: Decimal
    let transactionHash: String?
}

struct RepayResult {
    let repaidAmount: Decimal
    let remainingDebt: Decimal
    let newHealthFactor: Decimal
    let transactionHash: String?
}

struct LiquidationResult {
    let liquidatedDebt: Decimal
    let collateralReceived: Decimal
    let remainingDebt: Decimal
    let liquidationBonus: Decimal
    let transactionHash: String?
}

struct PoolConfiguration {
    let flashLoanPremium: Decimal
    let reserveFactor: Decimal
    let emissionPerSecond: Decimal
    let isPaused: Bool
    let isFrozen: Bool
    let maxReserves: Int
}