import Foundation
import Combine

// MARK: - User Position Service Protocol
protocol UserPositionServiceProtocol {
    // Position Queries
    func getUserPosition(contractId: String, userId: String) -> AnyPublisher<UserPosition, UserPositionError>
    func getUserPositions(contractId: String, userId: String) -> AnyPublisher<[UserPosition], UserPositionError>
    func getHealthFactor(contractId: String, userId: String) -> AnyPublisher<Decimal, UserPositionError>
    
    // Collateral Information
    func getUserCollateral(contractId: String, userId: String) -> AnyPublisher<[AssetPosition], UserPositionError>
    func getUserDebt(contractId: String, userId: String) -> AnyPublisher<[AssetPosition], UserPositionError>
    func getAvailableBorrowPower(contractId: String, userId: String) -> AnyPublisher<Decimal, UserPositionError>
    
    // Position Analysis
    func getLiquidationThreshold(contractId: String, userId: String) -> AnyPublisher<Decimal, UserPositionError>
    func getMaxLTV(contractId: String, userId: String) -> AnyPublisher<Decimal, UserPositionError>
    func isPositionHealthy(contractId: String, userId: String) -> AnyPublisher<Bool, UserPositionError>
    
    // Account Data
    func getAccountData(contractId: String, userId: String) -> AnyPublisher<AccountData, UserPositionError>
    func getReserveUserData(contractId: String, userId: String, asset: String) -> AnyPublisher<ReserveUserData, UserPositionError>
}

// MARK: - User Position Error
enum UserPositionError: LocalizedError {
    case networkError(NetworkError)
    case parsingError(ParsingError)
    case userNotFound
    case positionNotFound
    case invalidUserId
    case noCollateral
    case noDebt
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "User position network error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "User position parsing error: \(error.localizedDescription)"
        case .userNotFound:
            return "User not found"
        case .positionNotFound:
            return "Position not found"
        case .invalidUserId:
            return "Invalid user ID"
        case .noCollateral:
            return "User has no collateral"
        case .noDebt:
            return "User has no debt"
        }
    }
}

// MARK: - Data Types
struct AccountData {
    let totalCollateralValue: Decimal
    let totalDebtValue: Decimal
    let availableBorrowsValue: Decimal
    let currentLiquidationThreshold: Decimal
    let ltv: Decimal
    let healthFactor: Decimal
    let eModeCategory: Int?
}

struct ReserveUserData {
    let asset: String
    let currentATokenBalance: Decimal
    let currentStableDebt: Decimal
    let currentVariableDebt: Decimal
    let principalStableDebt: Decimal
    let scaledVariableDebt: Decimal
    let stableBorrowRate: Decimal
    let liquidityRate: Decimal
    let stableRateLastUpdated: Date
    let usageAsCollateralEnabled: Bool
}