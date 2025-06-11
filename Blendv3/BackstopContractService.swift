import Foundation
import Combine
import StellarSDK

// MARK: - Backstop Contract Service Protocol
protocol BackstopContractServiceProtocol {
    // Backstop Information
    func getBackstopData(contractId: String, poolId: String) -> AnyPublisher<BackstopData, BackstopError>
    func getTotalDeposits(contractId: String, poolId: String) -> AnyPublisher<Decimal, BackstopError>
    func getTotalShares(contractId: String, poolId: String) -> AnyPublisher<Decimal, BackstopError>
    
    // Deposit/Withdraw Operations
    func deposit(contractId: String, poolId: String, amount: Decimal) -> AnyPublisher<BackstopDepositResult, BackstopError>
    func queueWithdrawal(contractId: String, poolId: String, shares: Decimal) -> AnyPublisher<BackstopQueueResult, BackstopError>
    func withdraw(contractId: String, poolId: String, queuePosition: Int) -> AnyPublisher<BackstopWithdrawResult, BackstopError>
    func cancelWithdrawal(contractId: String, poolId: String, queuePosition: Int) -> AnyPublisher<BackstopCancelResult, BackstopError>
    
    // User Information
    func getUserBackstopPosition(contractId: String, poolId: String, userId: String) -> AnyPublisher<UserBackstopPosition, BackstopError>
    func getUserQueuedWithdrawals(contractId: String, poolId: String, userId: String) -> AnyPublisher<[QueuedWithdrawal], BackstopError>
    
    // Pool Coverage
    func drawDownBackstop(contractId: String, poolId: String, amount: Decimal) -> AnyPublisher<DrawDownResult, BackstopError>
    func replenishBackstop(contractId: String, poolId: String, amount: Decimal) -> AnyPublisher<ReplenishResult, BackstopError>
}

// MARK: - Backstop Error
enum BackstopError: LocalizedError {
    case networkError(NetworkError)
    case parsingError(ParsingError)
    case insufficientBalance
    case withdrawalQueueFull
    case withdrawalNotReady
    case invalidQueuePosition
    case poolNotFound
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Backstop network error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Backstop parsing error: \(error.localizedDescription)"
        case .insufficientBalance:
            return "Insufficient balance"
        case .withdrawalQueueFull:
            return "Withdrawal queue is full"
        case .withdrawalNotReady:
            return "Withdrawal is not ready yet"
        case .invalidQueuePosition:
            return "Invalid queue position"
        case .poolNotFound:
            return "Pool not found"
        case .unauthorized:
            return "Unauthorized operation"
        }
    }
}

// MARK: - Result Types
struct BackstopDepositResult {
    let shares: Decimal
    let depositedAmount: Decimal
    let newTotalDeposits: Decimal
    let transactionHash: String?
}

struct BackstopQueueResult {
    let queuePosition: Int
    let shares: Decimal
    let expectedWithdrawTime: Date
    let transactionHash: String?
}

struct BackstopWithdrawResult {
    let withdrawnAmount: Decimal
    let sharesBurned: Decimal
    let remainingQueuedAmount: Decimal
    let transactionHash: String?
}

struct BackstopCancelResult {
    let cancelledShares: Decimal
    let queuePosition: Int
    let transactionHash: String?
}

struct UserBackstopPosition {
    let userId: String
    let poolId: String
    let shares: Decimal
    let depositedAmount: Decimal
    let queuedWithdrawals: Decimal
}

struct QueuedWithdrawal {
    let queuePosition: Int
    let shares: Decimal
    let requestTime: Date
    let availableTime: Date
    let amount: Decimal
}

struct DrawDownResult {
    let drawnAmount: Decimal
    let remainingBackstop: Decimal
    let transactionHash: String?
}

struct ReplenishResult {
    let replenishedAmount: Decimal
    let newTotalBackstop: Decimal
    let transactionHash: String?
}

// MARK: - Backstop Contract Service Implementation
final class BackstopContractService: BackstopContractServiceProtocol {
    
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
    
    // MARK: - Backstop Information
    
    func getBackstopData(contractId: String, poolId: String) -> AnyPublisher<BackstopData, BackstopError> {
        let args: [SCVal] = [
            .symbol(poolId)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_backstop_data", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.poolNotFound
                }
                
                return try self.blendParser.parseBackstopData(result)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getTotalDeposits(contractId: String, poolId: String) -> AnyPublisher<Decimal, BackstopError> {
        let args: [SCVal] = [
            .symbol(poolId)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_total_deposits", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.poolNotFound
                }
                
                guard let deposits = self.blendParser.parseSCVal(result) as? Decimal else {
                    throw BackstopError.parsingError(.typeMismatch(expected: "Decimal", actual: String(describing: result)))
                }
                
                return deposits / 10_000_000 // Convert from 7 decimals
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getTotalShares(contractId: String, poolId: String) -> AnyPublisher<Decimal, BackstopError> {
        let args: [SCVal] = [
            .symbol(poolId)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_total_shares", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.poolNotFound
                }
                
                guard let shares = self.blendParser.parseSCVal(result) as? Decimal else {
                    throw BackstopError.parsingError(.typeMismatch(expected: "Decimal", actual: String(describing: result)))
                }
                
                return shares / 10_000_000
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Deposit/Withdraw Operations
    
    func deposit(contractId: String, poolId: String, amount: Decimal) -> AnyPublisher<BackstopDepositResult, BackstopError> {
        let amountI128 = convertDecimalToI128(amount, decimals: 7)
        
        let args: [SCVal] = [
            .symbol(poolId),
            .i128(amountI128)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "deposit", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.networkError(.noData)
                }
                
                return try self.parseDepositResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func queueWithdrawal(contractId: String, poolId: String, shares: Decimal) -> AnyPublisher<BackstopQueueResult, BackstopError> {
        let sharesI128 = convertDecimalToI128(shares, decimals: 7)
        
        let args: [SCVal] = [
            .symbol(poolId),
            .i128(sharesI128)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "queue_withdrawal", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.networkError(.noData)
                }
                
                return try self.parseQueueResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func withdraw(contractId: String, poolId: String, queuePosition: Int) -> AnyPublisher<BackstopWithdrawResult, BackstopError> {
        let args: [SCVal] = [
            .symbol(poolId),
            .u32(UInt32(queuePosition))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "withdraw", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.withdrawalNotReady
                }
                
                return try self.parseWithdrawResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func cancelWithdrawal(contractId: String, poolId: String, queuePosition: Int) -> AnyPublisher<BackstopCancelResult, BackstopError> {
        let args: [SCVal] = [
            .symbol(poolId),
            .u32(UInt32(queuePosition))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "cancel_withdrawal", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.invalidQueuePosition
                }
                
                return try self.parseCancelResult(result, queuePosition: queuePosition, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - User Information
    
    func getUserBackstopPosition(contractId: String, poolId: String, userId: String) -> AnyPublisher<UserBackstopPosition, BackstopError> {
        let args: [SCVal] = [
            .symbol(poolId),
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_user_position", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.poolNotFound
                }
                
                return try self.parseUserPosition(result, userId: userId, poolId: poolId)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getUserQueuedWithdrawals(contractId: String, poolId: String, userId: String) -> AnyPublisher<[QueuedWithdrawal], BackstopError> {
        let args: [SCVal] = [
            .symbol(poolId),
            .address(try! SCAddress(contractId: userId))
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "get_user_queued_withdrawals", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result,
                      case .vec(let withdrawalsVec) = result else {
                    return []
                }
                
                return withdrawalsVec.compactMap { self.parseQueuedWithdrawal($0) }
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Pool Coverage
    
    func drawDownBackstop(contractId: String, poolId: String, amount: Decimal) -> AnyPublisher<DrawDownResult, BackstopError> {
        let amountI128 = convertDecimalToI128(amount, decimals: 7)
        
        let args: [SCVal] = [
            .symbol(poolId),
            .i128(amountI128)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "draw_down", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.insufficientBalance
                }
                
                return try self.parseDrawDownResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func replenishBackstop(contractId: String, poolId: String, amount: Decimal) -> AnyPublisher<ReplenishResult, BackstopError> {
        let amountI128 = convertDecimalToI128(amount, decimals: 7)
        
        let args: [SCVal] = [
            .symbol(poolId),
            .i128(amountI128)
        ]
        
        return networkService
            .invokeContract(contractId: contractId, method: "replenish", args: args)
            .tryMap { [weak self] response in
                guard let self = self,
                      let result = response.result else {
                    throw BackstopError.networkError(.noData)
                }
                
                return try self.parseReplenishResult(result, transactionHash: response.transactionHash)
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseDepositResult(_ scVal: SCVal, transactionHash: String?) throws -> BackstopDepositResult {
        guard case .map(let entries) = scVal else {
            throw BackstopError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var result = BackstopDepositResult(
            shares: 0,
            depositedAmount: 0,
            newTotalDeposits: 0,
            transactionHash: transactionHash
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "shares":
                result.shares = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "deposited_amount":
                result.depositedAmount = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "new_total_deposits":
                result.newTotalDeposits = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            default:
                break
            }
        }
        
        return result
    }
    
    private func parseQueueResult(_ scVal: SCVal, transactionHash: String?) throws -> BackstopQueueResult {
        guard case .map(let entries) = scVal else {
            throw BackstopError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var result = BackstopQueueResult(
            queuePosition: 0,
            shares: 0,
            expectedWithdrawTime: Date(),
            transactionHash: transactionHash
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "queue_position":
                result.queuePosition = blendParser.parseSCVal(entry.val) as? Int ?? 0
            case "shares":
                result.shares = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "expected_withdraw_time":
                result.expectedWithdrawTime = blendParser.parseSCVal(entry.val) as? Date ?? Date()
            default:
                break
            }
        }
        
        return result
    }
    
    private func parseWithdrawResult(_ scVal: SCVal, transactionHash: String?) throws -> BackstopWithdrawResult {
        guard case .map(let entries) = scVal else {
            throw BackstopError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var result = BackstopWithdrawResult(
            withdrawnAmount: 0,
            sharesBurned: 0,
            remainingQueuedAmount: 0,
            transactionHash: transactionHash
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "withdrawn_amount":
                result.withdrawnAmount = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "shares_burned":
                result.sharesBurned = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "remaining_queued_amount":
                result.remainingQueuedAmount = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            default:
                break
            }
        }
        
        return result
    }
    
    private func parseCancelResult(_ scVal: SCVal, queuePosition: Int, transactionHash: String?) throws -> BackstopCancelResult {
        guard case .map(let entries) = scVal else {
            throw BackstopError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var result = BackstopCancelResult(
            cancelledShares: 0,
            queuePosition: queuePosition,
            transactionHash: transactionHash
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "cancelled_shares":
                result.cancelledShares = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            default:
                break
            }
        }
        
        return result
    }
    
    private func parseUserPosition(_ scVal: SCVal, userId: String, poolId: String) throws -> UserBackstopPosition {
        guard case .map(let entries) = scVal else {
            throw BackstopError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var position = UserBackstopPosition(
            userId: userId,
            poolId: poolId,
            shares: 0,
            depositedAmount: 0,
            queuedWithdrawals: 0
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "shares":
                position.shares = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "deposited_amount":
                position.depositedAmount = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "queued_withdrawals":
                position.queuedWithdrawals = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            default:
                break
            }
        }
        
        return position
    }
    
    private func parseQueuedWithdrawal(_ scVal: SCVal) -> QueuedWithdrawal? {
        guard case .map(let entries) = scVal else { return nil }
        
        var withdrawal = QueuedWithdrawal(
            queuePosition: 0,
            shares: 0,
            requestTime: Date(),
            availableTime: Date(),
            amount: 0
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "queue_position":
                withdrawal.queuePosition = blendParser.parseSCVal(entry.val) as? Int ?? 0
            case "shares":
                withdrawal.shares = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "request_time":
                withdrawal.requestTime = blendParser.parseSCVal(entry.val) as? Date ?? Date()
            case "available_time":
                withdrawal.availableTime = blendParser.parseSCVal(entry.val) as? Date ?? Date()
            case "amount":
                withdrawal.amount = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            default:
                break
            }
        }
        
        return withdrawal
    }
    
    private func parseDrawDownResult(_ scVal: SCVal, transactionHash: String?) throws -> DrawDownResult {
        guard case .map(let entries) = scVal else {
            throw BackstopError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var result = DrawDownResult(
            drawnAmount: 0,
            remainingBackstop: 0,
            transactionHash: transactionHash
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "drawn_amount":
                result.drawnAmount = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "remaining_backstop":
                result.remainingBackstop = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            default:
                break
            }
        }
        
        return result
    }
    
    private func parseReplenishResult(_ scVal: SCVal, transactionHash: String?) throws -> ReplenishResult {
        guard case .map(let entries) = scVal else {
            throw BackstopError.parsingError(.typeMismatch(expected: "map", actual: String(describing: scVal)))
        }
        
        var result = ReplenishResult(
            replenishedAmount: 0,
            newTotalBackstop: 0,
            transactionHash: transactionHash
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "replenished_amount":
                result.replenishedAmount = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            case "new_total_backstop":
                result.newTotalBackstop = (blendParser.parseSCVal(entry.val) as? Decimal ?? 0) / 10_000_000
            default:
                break
            }
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private func convertDecimalToI128(_ decimal: Decimal, decimals: Int) -> SCI128Parts {
        let multiplier = Decimal(sign: .plus, exponent: decimals, significand: 1)
        let scaled = decimal * multiplier
        let intValue = NSDecimalNumber(decimal: scaled).int64Value
        
        return SCI128Parts(hi: intValue < 0 ? -1 : 0, lo: UInt64(bitPattern: intValue))
    }
    
    private func mapError(_ error: Error) -> BackstopError {
        if let backstopError = error as? BackstopError {
            return backstopError
        } else if let networkError = error as? NetworkError {
            return .networkError(networkError)
        } else if let parsingError = error as? ParsingError {
            return .parsingError(parsingError)
        } else {
            return .networkError(.networkError(error))
        }
    }
}