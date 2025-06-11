import Foundation
import Combine
import StellarSDK

// MARK: - Pool Service Implementation
final class PoolService: PoolServiceProtocol {
    
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
    
    // MARK: - Pool Information
    
    func getPoolData(contractId: String) -> AnyPublisher<PoolData, PoolError> {
        return networkService
            .invokeContract(contractId: contractId, method: "get_pool_data", args: [])
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw PoolError.networkError(.noData)
                }
                
                return try self.blendParser.parsePoolData(result)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getPoolReserves(contractId: String) -> AnyPublisher<[ReserveData], PoolError> {
        return networkService
            .invokeContract(contractId: contractId, method: "get_reserves", args: [])
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let reserveVec) = result else {
                    throw PoolError.networkError(.noData)
                }
                
                return try reserveVec.map { try self.blendParser.parseReserveData($0) }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getPoolStatus(contractId: String) -> AnyPublisher<PoolStatus, PoolError> {
        return networkService
            .invokeContract(contractId: contractId, method: "get_status", args: [])
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .symbol(let status) = result else {
                    throw PoolError.networkError(.noData)
                }
                
                switch status.lowercased() {
                case "active":
                    return .active
                case "frozen":
                    return .frozen
                case "paused":
                    return .paused
                default:
                    return .active
                }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Supply Operations
    
    func supply(contractId: String, asset: String, amount: Decimal, onBehalfOf: String?) -> AnyPublisher<SupplyResult, PoolError> {
        // Convert amount to contract format (7 decimals)
        let amountI128 = convertDecimalToI128(amount, decimals: 7)
        
        var args: [SCVal] = [
            .symbol(asset),
            .i128(amountI128)
        ]
        
        if let onBehalfOf = onBehalfOf {
            args.append(.address(try! SCAddress(contractId: onBehalfOf)))
        }
        
        return networkService
            .invokeContract(contractId: contractId, method: "supply", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw PoolError.networkError(.noData)
                }
                
                return try self.parseSupplyResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func withdraw(contractId: String, asset: String, amount: Decimal, to: String?) -> AnyPublisher<WithdrawResult, PoolError> {
        let amountI128 = convertDecimalToI128(amount, decimals: 7)
        
        var args: [SCVal] = [
            .symbol(asset),
            .i128(amountI128)
        ]
        
        if let to = to {
            args.append(.address(try! SCAddress(contractId: to)))
        }
        
        return networkService
            .invokeContract(contractId: contractId, method: "withdraw", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw PoolError.networkError(.noData)
                }
                
                return try self.parseWithdrawResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Borrow Operations
    
    func borrow(contractId: String, asset: String, amount: Decimal) -> AnyPublisher<BorrowResult, PoolError> {
        let amountI128 = convertDecimalToI128(amount, decimals: 7)
        
        let args: [SCVal] = [
            .symbol(asset),
            .i128(amountI128)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "borrow", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw PoolError.networkError(.noData)
                }
                
                return try self.parseBorrowResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func repay(contractId: String, asset: String, amount: Decimal, onBehalfOf: String?) -> AnyPublisher<RepayResult, PoolError> {
        let amountI128 = convertDecimalToI128(amount, decimals: 7)
        
        var args: [SCVal] = [
            .symbol(asset),
            .i128(amountI128)
        ]
        
        if let onBehalfOf = onBehalfOf {
            args.append(.address(try! SCAddress(contractId: onBehalfOf)))
        }
        
        return networkService
            .invokeContract(contractId: contractId, method: "repay", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw PoolError.networkError(.noData)
                }
                
                return try self.parseRepayResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Liquidation
    
    func liquidate(contractId: String, user: String, debtAsset: String, collateralAsset: String, amount: Decimal) -> AnyPublisher<LiquidationResult, PoolError> {
        let amountI128 = convertDecimalToI128(amount, decimals: 7)
        
        let args: [SCVal] = [
            .address(try! SCAddress(contractId: user)),
            .symbol(debtAsset),
            .symbol(collateralAsset),
            .i128(amountI128)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "liquidate", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw PoolError.networkError(.noData)
                }
                
                return try self.parseLiquidationResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Pool Configuration
    
    func getReserveConfiguration(contractId: String, asset: String) -> AnyPublisher<ReserveConfiguration, PoolError> {
        let args: [SCVal] = [.symbol(asset)]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_reserve_config", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw PoolError.networkError(.noData)
                }
                
                guard case .map(let entries) = result else {
                    throw PoolError.parsingError(.typeMismatch(expected: "map", actual: String(describing: result)))
                }
                
                // Parse the configuration from the map
                return try self.parseReserveConfiguration(entries)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getPoolConfiguration(contractId: String) -> AnyPublisher<PoolConfiguration, PoolError> {
        return networkService
            .invokeContract(contractId: contractId, method: "get_pool_config", args: [])
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw PoolError.networkError(.noData)
                }
                
                return try self.parsePoolConfiguration(result)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseSupplyResult(_ scVal: SCVal, transactionHash: String?) throws -> SupplyResult {
        guard case .map(let entries) = scVal else {
            throw PoolError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var shares: Decimal = 0
        var suppliedAmount: Decimal = 0
        var newTotalSupply: Decimal = 0
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "shares":
                shares = parseDecimalFromSCVal(entry.val) ?? 0
            case "supplied_amount":
                suppliedAmount = parseDecimalFromSCVal(entry.val) ?? 0
            case "new_total_supply":
                newTotalSupply = parseDecimalFromSCVal(entry.val) ?? 0
            default:
                break
            }
        }
        
        return SupplyResult(
            shares: shares,
            suppliedAmount: suppliedAmount,
            newTotalSupply: newTotalSupply,
            transactionHash: transactionHash
        )
    }
    
    private func parseWithdrawResult(_ scVal: SCVal, transactionHash: String?) throws -> WithdrawResult {
        guard case .map(let entries) = scVal else {
            throw PoolError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var withdrawnAmount: Decimal = 0
        var sharesBurned: Decimal = 0
        var remainingSupply: Decimal = 0
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "withdrawn_amount":
                withdrawnAmount = parseDecimalFromSCVal(entry.val) ?? 0
            case "shares_burned":
                sharesBurned = parseDecimalFromSCVal(entry.val) ?? 0
            case "remaining_supply":
                remainingSupply = parseDecimalFromSCVal(entry.val) ?? 0
            default:
                break
            }
        }
        
        return WithdrawResult(
            withdrawnAmount: withdrawnAmount,
            sharesBurned: sharesBurned,
            remainingSupply: remainingSupply,
            transactionHash: transactionHash
        )
    }
    
    private func parseBorrowResult(_ scVal: SCVal, transactionHash: String?) throws -> BorrowResult {
        guard case .map(let entries) = scVal else {
            throw PoolError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var borrowedAmount: Decimal = 0
        var newTotalBorrowed: Decimal = 0
        var newHealthFactor: Decimal = 0
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "borrowed_amount":
                borrowedAmount = parseDecimalFromSCVal(entry.val) ?? 0
            case "new_total_borrowed":
                newTotalBorrowed = parseDecimalFromSCVal(entry.val) ?? 0
            case "new_health_factor":
                newHealthFactor = parseDecimalFromSCVal(entry.val) ?? 0
            default:
                break
            }
        }
        
        return BorrowResult(
            borrowedAmount: borrowedAmount,
            newTotalBorrowed: newTotalBorrowed,
            newHealthFactor: newHealthFactor,
            transactionHash: transactionHash
        )
    }
    
    private func parseRepayResult(_ scVal: SCVal, transactionHash: String?) throws -> RepayResult {
        guard case .map(let entries) = scVal else {
            throw PoolError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var repaidAmount: Decimal = 0
        var remainingDebt: Decimal = 0
        var newHealthFactor: Decimal = 0
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "repaid_amount":
                repaidAmount = parseDecimalFromSCVal(entry.val) ?? 0
            case "remaining_debt":
                remainingDebt = parseDecimalFromSCVal(entry.val) ?? 0
            case "new_health_factor":
                newHealthFactor = parseDecimalFromSCVal(entry.val) ?? 0
            default:
                break
            }
        }
        
        return RepayResult(
            repaidAmount: repaidAmount,
            remainingDebt: remainingDebt,
            newHealthFactor: newHealthFactor,
            transactionHash: transactionHash
        )
    }
    
    private func parseLiquidationResult(_ scVal: SCVal, transactionHash: String?) throws -> LiquidationResult {
        guard case .map(let entries) = scVal else {
            throw PoolError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var liquidatedDebt: Decimal = 0
        var collateralReceived: Decimal = 0
        var remainingDebt: Decimal = 0
        var liquidationBonus: Decimal = 0
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "liquidated_debt":
                liquidatedDebt = parseDecimalFromSCVal(entry.val) ?? 0
            case "collateral_received":
                collateralReceived = parseDecimalFromSCVal(entry.val) ?? 0
            case "remaining_debt":
                remainingDebt = parseDecimalFromSCVal(entry.val) ?? 0
            case "liquidation_bonus":
                liquidationBonus = parseDecimalFromSCVal(entry.val) ?? 0
            default:
                break
            }
        }
        
        return LiquidationResult(
            liquidatedDebt: liquidatedDebt,
            collateralReceived: collateralReceived,
            remainingDebt: remainingDebt,
            liquidationBonus: liquidationBonus,
            transactionHash: transactionHash
        )
    }
    
    private func parseReserveConfiguration(_ entries: [SCMapEntry]) throws -> ReserveConfiguration {
        var config = ReserveConfiguration(
            ltv: 0,
            liquidationThreshold: 0,
            liquidationBonus: 0,
            reserveFactor: 0,
            isActive: true,
            isFrozen: false,
            borrowingEnabled: true
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "ltv":
                config.ltv = (parseDecimalFromSCVal(entry.val) ?? 0) / 10000
            case "liquidation_threshold":
                config.liquidationThreshold = (parseDecimalFromSCVal(entry.val) ?? 0) / 10000
            case "liquidation_bonus":
                config.liquidationBonus = (parseDecimalFromSCVal(entry.val) ?? 0) / 10000
            case "reserve_factor":
                config.reserveFactor = (parseDecimalFromSCVal(entry.val) ?? 0) / 10000
            case "is_active":
                config.isActive = blendParser.parseSCVal(entry.val) as? Bool ?? true
            case "is_frozen":
                config.isFrozen = blendParser.parseSCVal(entry.val) as? Bool ?? false
            case "borrowing_enabled":
                config.borrowingEnabled = blendParser.parseSCVal(entry.val) as? Bool ?? true
            default:
                break
            }
        }
        
        return config
    }
    
    private func parsePoolConfiguration(_ scVal: SCVal) throws -> PoolConfiguration {
        guard case .map(let entries) = scVal else {
            throw PoolError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var config = PoolConfiguration(
            flashLoanPremium: 0,
            reserveFactor: 0,
            emissionPerSecond: 0,
            isPaused: false,
            isFrozen: false,
            maxReserves: 128
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "flash_loan_premium":
                config.flashLoanPremium = (parseDecimalFromSCVal(entry.val) ?? 0) / 10000
            case "reserve_factor":
                config.reserveFactor = (parseDecimalFromSCVal(entry.val) ?? 0) / 10000
            case "emission_per_second":
                config.emissionPerSecond = parseDecimalFromSCVal(entry.val) ?? 0
            case "is_paused":
                config.isPaused = blendParser.parseSCVal(entry.val) as? Bool ?? false
            case "is_frozen":
                config.isFrozen = blendParser.parseSCVal(entry.val) as? Bool ?? false
            case "max_reserves":
                config.maxReserves = blendParser.parseSCVal(entry.val) as? Int ?? 128
            default:
                break
            }
        }
        
        return config
    }
    
    // MARK: - Helper Methods
    
    private func convertDecimalToI128(_ decimal: Decimal, decimals: Int) -> SCI128Parts {
        let multiplier = Decimal(sign: .plus, exponent: decimals, significand: 1)
        let scaled = decimal * multiplier
        
        // Convert to Int64 (simplified for demonstration)
        let intValue = NSDecimalNumber(decimal: scaled).int64Value
        
        return SCI128Parts(hi: intValue < 0 ? -1 : 0, lo: UInt64(bitPattern: intValue))
    }
    
    private func parseDecimalFromSCVal(_ scVal: SCVal) -> Decimal? {
        return blendParser.parseSCVal(scVal) as? Decimal
    }
    
    private func mapError(_ error: Error) -> PoolError {
        if let poolError = error as? PoolError {
            return poolError
        } else if let networkError = error as? NetworkError {
            return .networkError(networkError)
        } else if let parsingError = error as? ParsingError {
            return .parsingError(parsingError)
        } else {
            return .networkError(.networkError(error))
        }
    }
}