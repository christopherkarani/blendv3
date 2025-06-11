import Foundation
import Combine
import StellarSDK

// MARK: - User Position Service Implementation
final class UserPositionService: UserPositionServiceProtocol {
    
    // MARK: - Properties
    private let networkService: NetworkServiceProtocol
    private let blendParser: BlendParserProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(networkService: NetworkServiceProtocol = NetworkService(),
         blendParser: BlendParserProtocol = BlendParser()) {
        self.networkService = networkService
        self.blendParser = blendParser
    }
    
    // MARK: - Position Queries
    
    func getUserPosition(contractId: String, userId: String) -> AnyPublisher<UserPosition, UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_user_position", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw UserPositionError.positionNotFound
                }
                
                return try self.blendParser.parseUserPosition(result)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getUserPositions(contractId: String, userId: String) -> AnyPublisher<[UserPosition], UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_user_positions", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let positionsVec) = result else {
                    throw UserPositionError.positionNotFound
                }
                
                return try positionsVec.map { try self.blendParser.parseUserPosition($0) }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getHealthFactor(contractId: String, userId: String) -> AnyPublisher<Decimal, UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_health_factor", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw UserPositionError.userNotFound
                }
                
                guard let healthFactor = self.blendParser.parseSCVal(result) as? Decimal else {
                    throw UserPositionError.parsingError(.typeMismatch(expected: "Decimal", actual: String(describing: result)))
                }
                
                return healthFactor / 10_000_000 // Convert from 7 decimals
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Collateral Information
    
    func getUserCollateral(contractId: String, userId: String) -> AnyPublisher<[AssetPosition], UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_user_collateral", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let collateralVec) = result else {
                    throw UserPositionError.noCollateral
                }
                
                return collateralVec.compactMap { self.parseAssetPosition($0) }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getUserDebt(contractId: String, userId: String) -> AnyPublisher<[AssetPosition], UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_user_debt", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let debtVec) = result else {
                    throw UserPositionError.noDebt
                }
                
                return debtVec.compactMap { self.parseAssetPosition($0) }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getAvailableBorrowPower(contractId: String, userId: String) -> AnyPublisher<Decimal, UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_available_borrow_power", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw UserPositionError.userNotFound
                }
                
                guard let borrowPower = self.blendParser.parseSCVal(result) as? Decimal else {
                    throw UserPositionError.parsingError(.typeMismatch(expected: "Decimal", actual: String(describing: result)))
                }
                
                return borrowPower / 10_000_000 // Convert from 7 decimals
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Position Analysis
    
    func getLiquidationThreshold(contractId: String, userId: String) -> AnyPublisher<Decimal, UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_liquidation_threshold", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw UserPositionError.userNotFound
                }
                
                guard let threshold = self.blendParser.parseSCVal(result) as? Decimal else {
                    throw UserPositionError.parsingError(.typeMismatch(expected: "Decimal", actual: String(describing: result)))
                }
                
                return threshold / 10000 // Convert from basis points
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getMaxLTV(contractId: String, userId: String) -> AnyPublisher<Decimal, UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_max_ltv", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw UserPositionError.userNotFound
                }
                
                guard let ltv = self.blendParser.parseSCVal(result) as? Decimal else {
                    throw UserPositionError.parsingError(.typeMismatch(expected: "Decimal", actual: String(describing: result)))
                }
                
                return ltv / 10000 // Convert from basis points
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func isPositionHealthy(contractId: String, userId: String) -> AnyPublisher<Bool, UserPositionError> {
        return getHealthFactor(contractId: contractId, userId: userId)
            .map { healthFactor in
                healthFactor >= 1.0
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Account Data
    
    func getAccountData(contractId: String, userId: String) -> AnyPublisher<AccountData, UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_account_data", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw UserPositionError.userNotFound
                }
                
                return try self.parseAccountData(result)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getReserveUserData(contractId: String, userId: String, asset: String) -> AnyPublisher<ReserveUserData, UserPositionError> {
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: userId)),
            .symbol(asset)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_reserve_user_data", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw UserPositionError.userNotFound
                }
                
                return try self.parseReserveUserData(result, asset: asset)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseAssetPosition(_ scVal: SCVal) -> AssetPosition? {
        guard case .map(let entries) = scVal else { return nil }
        
        var position = AssetPosition(
            asset: "",
            amount: 0,
            shares: 0,
            value: 0
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "asset":
                position.asset = blendParser.parseSCVal(entry.val) as? String ?? ""
            case "amount":
                if let amount = blendParser.parseSCVal(entry.val) as? Decimal {
                    position.amount = amount / 10_000_000 // Convert from 7 decimals
                }
            case "shares":
                if let shares = blendParser.parseSCVal(entry.val) as? Decimal {
                    position.shares = shares / 10_000_000
                }
            case "value":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    position.value = value / 10_000_000
                }
            default:
                break
            }
        }
        
        return position.asset.isEmpty ? nil : position
    }
    
    private func parseAccountData(_ scVal: SCVal) throws -> AccountData {
        guard case .map(let entries) = scVal else {
            throw UserPositionError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var accountData = AccountData(
            totalCollateralValue: 0,
            totalDebtValue: 0,
            availableBorrowsValue: 0,
            currentLiquidationThreshold: 0,
            ltv: 0,
            healthFactor: 0,
            eModeCategory: nil
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "total_collateral_value":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    accountData.totalCollateralValue = value / 10_000_000
                }
            case "total_debt_value":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    accountData.totalDebtValue = value / 10_000_000
                }
            case "available_borrows_value":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    accountData.availableBorrowsValue = value / 10_000_000
                }
            case "current_liquidation_threshold":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    accountData.currentLiquidationThreshold = value / 10000 // basis points
                }
            case "ltv":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    accountData.ltv = value / 10000 // basis points
                }
            case "health_factor":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    accountData.healthFactor = value / 10_000_000
                }
            case "emode_category":
                accountData.eModeCategory = blendParser.parseSCVal(entry.val) as? Int
            default:
                break
            }
        }
        
        return accountData
    }
    
    private func parseReserveUserData(_ scVal: SCVal, asset: String) throws -> ReserveUserData {
        guard case .map(let entries) = scVal else {
            throw UserPositionError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var userData = ReserveUserData(
            asset: asset,
            currentATokenBalance: 0,
            currentStableDebt: 0,
            currentVariableDebt: 0,
            principalStableDebt: 0,
            scaledVariableDebt: 0,
            stableBorrowRate: 0,
            liquidityRate: 0,
            stableRateLastUpdated: Date(),
            usageAsCollateralEnabled: true
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "current_atoken_balance":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    userData.currentATokenBalance = value / 10_000_000
                }
            case "current_stable_debt":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    userData.currentStableDebt = value / 10_000_000
                }
            case "current_variable_debt":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    userData.currentVariableDebt = value / 10_000_000
                }
            case "principal_stable_debt":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    userData.principalStableDebt = value / 10_000_000
                }
            case "scaled_variable_debt":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    userData.scaledVariableDebt = value / 10_000_000
                }
            case "stable_borrow_rate":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    userData.stableBorrowRate = value / 10_000_000
                }
            case "liquidity_rate":
                if let value = blendParser.parseSCVal(entry.val) as? Decimal {
                    userData.liquidityRate = value / 10_000_000
                }
            case "stable_rate_last_updated":
                if let timestamp = blendParser.parseSCVal(entry.val) as? Date {
                    userData.stableRateLastUpdated = timestamp
                }
            case "usage_as_collateral_enabled":
                userData.usageAsCollateralEnabled = blendParser.parseSCVal(entry.val) as? Bool ?? true
            default:
                break
            }
        }
        
        return userData
    }
    
    // MARK: - Helper Methods
    
    private func mapError(_ error: Error) -> UserPositionError {
        if let positionError = error as? UserPositionError {
            return positionError
        } else if let networkError = error as? NetworkError {
            return .networkError(networkError)
        } else if let parsingError = error as? ParsingError {
            return .parsingError(parsingError)
        } else {
            return .networkError(.networkError(error))
        }
    }
}