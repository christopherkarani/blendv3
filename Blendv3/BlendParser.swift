import Foundation
import StellarSDK

// MARK: - Blend Parser Protocol
protocol BlendParserProtocol {
    // Core parsing methods
    func parseContractResponse<T: Decodable>(_ scVal: SCVal, as type: T.Type) throws -> T
    func parseSCVal(_ scVal: SCVal) -> Any?
    func parseTransactionResult(_ result: TransactionResult) throws -> ParsedTransactionResult
    func parseContractEvents(_ events: [DiagnosticEvent]) -> [ParsedContractEvent]
    func parseLedgerEntry(_ entry: LedgerEntry) throws -> ParsedLedgerEntry
    
    // Specialized parsing for Blend protocol
    func parseOracleData(_ scVal: SCVal) throws -> OracleData
    func parsePoolData(_ scVal: SCVal) throws -> PoolData
    func parseUserPosition(_ scVal: SCVal) throws -> UserPosition
    func parseBackstopData(_ scVal: SCVal) throws -> BackstopData
    func parseReserveData(_ scVal: SCVal) throws -> ReserveData
}

// MARK: - Parsing Error
enum ParsingError: LocalizedError {
    case invalidFormat(String)
    case typeMismatch(expected: String, actual: String)
    case missingField(String)
    case xdrDecodingFailed(String)
    case unsupportedType(String)
    case invalidContractData
    case conversionFailed(from: String, to: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return "Invalid format: \(message)"
        case .typeMismatch(let expected, let actual):
            return "Type mismatch: expected \(expected), got \(actual)"
        case .missingField(let field):
            return "Missing required field: \(field)"
        case .xdrDecodingFailed(let message):
            return "XDR decoding failed: \(message)"
        case .unsupportedType(let type):
            return "Unsupported type: \(type)"
        case .invalidContractData:
            return "Invalid contract data"
        case .conversionFailed(let from, let to):
            return "Failed to convert from \(from) to \(to)"
        }
    }
}

// MARK: - Parsed Result Types
struct ParsedTransactionResult {
    let success: Bool
    let returnValue: Any?
    let events: [ParsedContractEvent]
    let diagnosticEvents: [DiagnosticEvent]
    let cost: TransactionCost?
}

struct ParsedContractEvent {
    let contractId: String
    let eventType: String
    let data: [String: Any]
    let timestamp: Date?
}

struct ParsedLedgerEntry {
    let type: LedgerEntryType
    let data: Any
    let lastModified: UInt32
}

enum LedgerEntryType {
    case account
    case trustline
    case offer
    case contractData
    case contractCode
}

// MARK: - Blend Protocol Data Types
struct OracleData {
    let asset: String
    let price: Decimal
    let timestamp: Date
    let source: String
}

struct PoolData {
    let id: String
    let name: String
    let reserves: [ReserveData]
    let totalSupply: Decimal
    let totalBorrowed: Decimal
    let utilizationRate: Decimal
    let status: PoolStatus
}

enum PoolStatus {
    case active
    case frozen
    case paused
}

struct UserPosition {
    let userId: String
    let poolId: String
    let supplied: [AssetPosition]
    let borrowed: [AssetPosition]
    let healthFactor: Decimal
    let totalCollateralValue: Decimal
    let totalDebtValue: Decimal
}

struct AssetPosition {
    let asset: String
    let amount: Decimal
    let shares: Decimal
    let value: Decimal
}

struct BackstopData {
    let poolId: String
    let totalDeposits: Decimal
    let totalShares: Decimal
    let queuedForWithdrawal: Decimal
}

struct ReserveData {
    let asset: String
    let totalSupply: Decimal
    let totalBorrowed: Decimal
    let supplyRate: Decimal
    let borrowRate: Decimal
    let utilizationRate: Decimal
    let lastUpdateTimestamp: Date
    let configuration: ReserveConfiguration
}

struct ReserveConfiguration {
    let ltv: Decimal
    let liquidationThreshold: Decimal
    let liquidationBonus: Decimal
    let reserveFactor: Decimal
    let isActive: Bool
    let isFrozen: Bool
    let borrowingEnabled: Bool
}

// MARK: - Blend Parser Implementation
final class BlendParser: BlendParserProtocol {
    
    // MARK: - Properties
    private let dateFormatter = ISO8601DateFormatter()
    
    // MARK: - Core Parsing Methods
    
    func parseContractResponse<T: Decodable>(_ scVal: SCVal, as type: T.Type) throws -> T {
        let parsedValue = parseSCVal(scVal)
        guard let data = try? JSONSerialization.data(withJSONObject: parsedValue ?? NSNull()) else {
            throw ParsingError.conversionFailed(from: "SCVal", to: String(describing: T.self))
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ParsingError.conversionFailed(from: "SCVal", to: String(describing: T.self))
        }
    }
    
    func parseSCVal(_ scVal: SCVal) -> Any? {
        switch scVal {
        case .bool(let value):
            return value
            
        case .void:
            return nil
            
        case .error(let error):
            return ["error": parseError(error)]
            
        case .u32(let value):
            return Int(value)
            
        case .i32(let value):
            return value
            
        case .u64(let value):
            return value
            
        case .i64(let value):
            return value
            
        case .timepoint(let value):
            return Date(timeIntervalSince1970: TimeInterval(value))
            
        case .duration(let value):
            return TimeInterval(value)
            
        case .u128(let parts):
            return combineU128(hi: parts.hi, lo: parts.lo)
            
        case .i128(let parts):
            return combineI128(hi: parts.hi, lo: parts.lo)
            
        case .u256(let parts):
            return combineU256(parts)
            
        case .i256(let parts):
            return combineI256(parts)
            
        case .bytes(let data):
            return data
            
        case .string(let value):
            return value
            
        case .symbol(let value):
            return value
            
        case .vec(let array):
            return array.map { parseSCVal($0) }
            
        case .map(let entries):
            var result: [String: Any] = [:]
            for entry in entries {
                if case .symbol(let key) = entry.key {
                    result[key] = parseSCVal(entry.val)
                } else if case .string(let key) = entry.key {
                    result[key] = parseSCVal(entry.val)
                }
            }
            return result
            
        case .address(let address):
            return parseAddress(address)
            
        case .contractInstance(let instance):
            return parseContractInstance(instance)
            
        case .ledgerKeyContractInstance:
            return "ledgerKeyContractInstance"
            
        case .ledgerKeyNonce(let nonce):
            return ["nonce": parseAddress(nonce)]
            
        default:
            return nil
        }
    }
    
    func parseTransactionResult(_ result: TransactionResult) throws -> ParsedTransactionResult {
        let success = result.result.isSuccess
        var returnValue: Any?
        var events: [ParsedContractEvent] = []
        
        if let innerResult = result.result.results?.first,
           case .invokeHostFunction(let hostFunctionResult) = innerResult {
            
            if case .success(let successValue) = hostFunctionResult {
                returnValue = parseSCVal(successValue)
            }
        }
        
        // Parse meta events if available
        if let meta = result.meta {
            events = parseMetaEvents(meta)
        }
        
        return ParsedTransactionResult(
            success: success,
            returnValue: returnValue,
            events: events,
            diagnosticEvents: [],
            cost: nil
        )
    }
    
    func parseContractEvents(_ events: [DiagnosticEvent]) -> [ParsedContractEvent] {
        return events.compactMap { event in
            guard let contractId = event.contractId else { return nil }
            
            var eventData: [String: Any] = [:]
            
            // Parse topics
            for (index, topic) in event.topics.enumerated() {
                eventData["topic_\(index)"] = parseSCVal(topic)
            }
            
            // Parse event data
            if let data = parseSCVal(event.data) {
                eventData["data"] = data
            }
            
            return ParsedContractEvent(
                contractId: contractId,
                eventType: event.type,
                data: eventData,
                timestamp: Date()
            )
        }
    }
    
    func parseLedgerEntry(_ entry: LedgerEntry) throws -> ParsedLedgerEntry {
        guard let ledgerEntryData = try? LedgerEntryData(xdr: entry.xdr) else {
            throw ParsingError.xdrDecodingFailed("Failed to decode ledger entry")
        }
        
        let type: LedgerEntryType
        let data: Any
        
        switch ledgerEntryData {
        case .account(let accountEntry):
            type = .account
            data = parseAccountEntry(accountEntry)
            
        case .trustline(let trustlineEntry):
            type = .trustline
            data = parseTrustlineEntry(trustlineEntry)
            
        case .offer(let offerEntry):
            type = .offer
            data = parseOfferEntry(offerEntry)
            
        case .contractData(let contractDataEntry):
            type = .contractData
            data = parseContractDataEntry(contractDataEntry)
            
        case .contractCode(let contractCodeEntry):
            type = .contractCode
            data = parseContractCodeEntry(contractCodeEntry)
            
        default:
            throw ParsingError.unsupportedType("Unsupported ledger entry type")
        }
        
        return ParsedLedgerEntry(
            type: type,
            data: data,
            lastModified: entry.lastModifiedLedgerSeq
        )
    }
    
    // MARK: - Specialized Blend Protocol Parsing
    
    func parseOracleData(_ scVal: SCVal) throws -> OracleData {
        guard case .map(let entries) = scVal else {
            throw ParsingError.typeMismatch(expected: "map", actual: String(describing: scVal))
        }
        
        var asset: String?
        var price: Decimal?
        var timestamp: Date?
        var source: String?
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "asset":
                asset = parseSCVal(entry.val) as? String
            case "price":
                if let priceValue = parseSCVal(entry.val) as? Int64 {
                    price = Decimal(priceValue) / 10_000_000 // 7 decimal places
                }
            case "timestamp":
                if let timestampValue = parseSCVal(entry.val) as? Date {
                    timestamp = timestampValue
                }
            case "source":
                source = parseSCVal(entry.val) as? String
            default:
                break
            }
        }
        
        guard let finalAsset = asset,
              let finalPrice = price,
              let finalTimestamp = timestamp,
              let finalSource = source else {
            throw ParsingError.missingField("Required oracle data fields")
        }
        
        return OracleData(
            asset: finalAsset,
            price: finalPrice,
            timestamp: finalTimestamp,
            source: finalSource
        )
    }
    
    func parsePoolData(_ scVal: SCVal) throws -> PoolData {
        guard case .map(let entries) = scVal else {
            throw ParsingError.typeMismatch(expected: "map", actual: String(describing: scVal))
        }
        
        var poolData = PoolData(
            id: "",
            name: "",
            reserves: [],
            totalSupply: 0,
            totalBorrowed: 0,
            utilizationRate: 0,
            status: .active
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "id":
                poolData.id = parseSCVal(entry.val) as? String ?? ""
            case "name":
                poolData.name = parseSCVal(entry.val) as? String ?? ""
            case "reserves":
                if case .vec(let reserveVec) = entry.val {
                    poolData.reserves = try reserveVec.compactMap { try parseReserveData($0) }
                }
            case "total_supply":
                if let value = parseDecimalValue(entry.val) {
                    poolData.totalSupply = value
                }
            case "total_borrowed":
                if let value = parseDecimalValue(entry.val) {
                    poolData.totalBorrowed = value
                }
            case "utilization_rate":
                if let value = parseDecimalValue(entry.val) {
                    poolData.utilizationRate = value
                }
            case "status":
                poolData.status = parsePoolStatus(entry.val) ?? .active
            default:
                break
            }
        }
        
        return poolData
    }
    
    func parseUserPosition(_ scVal: SCVal) throws -> UserPosition {
        guard case .map(let entries) = scVal else {
            throw ParsingError.typeMismatch(expected: "map", actual: String(describing: scVal))
        }
        
        var position = UserPosition(
            userId: "",
            poolId: "",
            supplied: [],
            borrowed: [],
            healthFactor: 0,
            totalCollateralValue: 0,
            totalDebtValue: 0
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "user_id":
                position.userId = parseSCVal(entry.val) as? String ?? ""
            case "pool_id":
                position.poolId = parseSCVal(entry.val) as? String ?? ""
            case "supplied":
                if case .vec(let suppliedVec) = entry.val {
                    position.supplied = suppliedVec.compactMap { parseAssetPosition($0) }
                }
            case "borrowed":
                if case .vec(let borrowedVec) = entry.val {
                    position.borrowed = borrowedVec.compactMap { parseAssetPosition($0) }
                }
            case "health_factor":
                if let value = parseDecimalValue(entry.val) {
                    position.healthFactor = value
                }
            case "total_collateral_value":
                if let value = parseDecimalValue(entry.val) {
                    position.totalCollateralValue = value
                }
            case "total_debt_value":
                if let value = parseDecimalValue(entry.val) {
                    position.totalDebtValue = value
                }
            default:
                break
            }
        }
        
        return position
    }
    
    func parseBackstopData(_ scVal: SCVal) throws -> BackstopData {
        guard case .map(let entries) = scVal else {
            throw ParsingError.typeMismatch(expected: "map", actual: String(describing: scVal))
        }
        
        var backstopData = BackstopData(
            poolId: "",
            totalDeposits: 0,
            totalShares: 0,
            queuedForWithdrawal: 0
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "pool_id":
                backstopData.poolId = parseSCVal(entry.val) as? String ?? ""
            case "total_deposits":
                if let value = parseDecimalValue(entry.val) {
                    backstopData.totalDeposits = value
                }
            case "total_shares":
                if let value = parseDecimalValue(entry.val) {
                    backstopData.totalShares = value
                }
            case "queued_for_withdrawal":
                if let value = parseDecimalValue(entry.val) {
                    backstopData.queuedForWithdrawal = value
                }
            default:
                break
            }
        }
        
        return backstopData
    }
    
    func parseReserveData(_ scVal: SCVal) throws -> ReserveData {
        guard case .map(let entries) = scVal else {
            throw ParsingError.typeMismatch(expected: "map", actual: String(describing: scVal))
        }
        
        var reserveData = ReserveData(
            asset: "",
            totalSupply: 0,
            totalBorrowed: 0,
            supplyRate: 0,
            borrowRate: 0,
            utilizationRate: 0,
            lastUpdateTimestamp: Date(),
            configuration: ReserveConfiguration(
                ltv: 0,
                liquidationThreshold: 0,
                liquidationBonus: 0,
                reserveFactor: 0,
                isActive: true,
                isFrozen: false,
                borrowingEnabled: true
            )
        )
        
        for entry in entries {
            guard case .symbol(let key) = entry.key else { continue }
            
            switch key {
            case "asset":
                reserveData.asset = parseSCVal(entry.val) as? String ?? ""
            case "total_supply":
                if let value = parseDecimalValue(entry.val) {
                    reserveData.totalSupply = value
                }
            case "total_borrowed":
                if let value = parseDecimalValue(entry.val) {
                    reserveData.totalBorrowed = value
                }
            case "supply_rate":
                if let value = parseDecimalValue(entry.val) {
                    reserveData.supplyRate = value
                }
            case "borrow_rate":
                if let value = parseDecimalValue(entry.val) {
                    reserveData.borrowRate = value
                }
            case "utilization_rate":
                if let value = parseDecimalValue(entry.val) {
                    reserveData.utilizationRate = value
                }
            case "last_update_timestamp":
                if let timestamp = parseSCVal(entry.val) as? Date {
                    reserveData.lastUpdateTimestamp = timestamp
                }
            case "configuration":
                if let config = parseReserveConfiguration(entry.val) {
                    reserveData.configuration = config
                }
            default:
                break
            }
        }
        
        return reserveData
    }
    
    // MARK: - Helper Methods
    
    private func parseError(_ error: SCError) -> String {
        switch error {
        case .contractError(let code):
            return "Contract error: \(code)"
        case .wasmVm:
            return "WASM VM error"
        case .context:
            return "Context error"
        case .storage:
            return "Storage error"
        case .object:
            return "Object error"
        case .crypto:
            return "Crypto error"
        case .events:
            return "Events error"
        case .budget:
            return "Budget error"
        case .value:
            return "Value error"
        case .auth:
            return "Auth error"
        }
    }
    
    private func combineU128(hi: UInt64, lo: UInt64) -> Decimal {
        let high = Decimal(hi) * Decimal(sign: .plus, exponent: 64, significand: 1)
        return high + Decimal(lo)
    }
    
    private func combineI128(hi: Int64, lo: UInt64) -> Decimal {
        let high = Decimal(hi) * Decimal(sign: .plus, exponent: 64, significand: 1)
        return high + Decimal(lo)
    }
    
    private func combineU256(_ parts: SCU256Parts) -> String {
        // For very large numbers, return as string
        return "U256(\(parts.hiHi),\(parts.hiLo),\(parts.loHi),\(parts.loLo))"
    }
    
    private func combineI256(_ parts: SCI256Parts) -> String {
        // For very large numbers, return as string
        return "I256(\(parts.hiHi),\(parts.hiLo),\(parts.loHi),\(parts.loLo))"
    }
    
    private func parseAddress(_ address: SCAddress) -> String {
        switch address {
        case .account(let accountId):
            return accountId.accountId
        case .contract(let contractId):
            return contractId.contractId
        }
    }
    
    private func parseContractInstance(_ instance: SCContractInstance) -> [String: Any] {
        return [
            "executable": parseContractExecutable(instance.executable),
            "storage": instance.storage?.map { ["key": parseSCVal($0.key), "value": parseSCVal($0.val)] } ?? []
        ]
    }
    
    private func parseContractExecutable(_ executable: SCContractExecutable) -> String {
        switch executable {
        case .wasmRef(let hash):
            return "wasmRef:\(hash.hexString)"
        case .stellarAsset:
            return "stellarAsset"
        }
    }
    
    private func parseMetaEvents(_ meta: TransactionMeta) -> [ParsedContractEvent] {
        // Implementation would parse transaction meta for contract events
        return []
    }
    
    private func parseAccountEntry(_ entry: AccountEntry) -> [String: Any] {
        return [
            "accountId": entry.accountID.accountId,
            "balance": entry.balance,
            "seqNum": entry.seqNum,
            "numSubEntries": entry.numSubEntries,
            "flags": entry.flags
        ]
    }
    
    private func parseTrustlineEntry(_ entry: TrustLineEntry) -> [String: Any] {
        return [
            "accountId": entry.accountID.accountId,
            "asset": parseAsset(entry.asset),
            "balance": entry.balance,
            "limit": entry.limit,
            "flags": entry.flags
        ]
    }
    
    private func parseOfferEntry(_ entry: OfferEntry) -> [String: Any] {
        return [
            "sellerId": entry.sellerID.accountId,
            "offerId": entry.offerID,
            "selling": parseAsset(entry.selling),
            "buying": parseAsset(entry.buying),
            "amount": entry.amount,
            "price": ["n": entry.price.n, "d": entry.price.d],
            "flags": entry.flags
        ]
    }
    
    private func parseContractDataEntry(_ entry: ContractDataEntry) -> [String: Any] {
        return [
            "contract": parseAddress(entry.contract),
            "key": parseSCVal(entry.key),
            "value": parseSCVal(entry.val),
            "durability": entry.durability
        ]
    }
    
    private func parseContractCodeEntry(_ entry: ContractCodeEntry) -> [String: Any] {
        return [
            "hash": entry.hash.hexString,
            "code": entry.code
        ]
    }
    
    private func parseAsset(_ asset: Asset) -> [String: Any] {
        switch asset {
        case .native:
            return ["type": "native"]
        case .alphanum4(let code, let issuer):
            return ["type": "alphanum4", "code": code, "issuer": issuer.accountId]
        case .alphanum12(let code, let issuer):
            return ["type": "alphanum12", "code": code, "issuer": issuer.accountId]
        }
    }
    
    private func parseDecimalValue(_ scVal: SCVal) -> Decimal? {
        switch scVal {
        case .u32(let value):
            return Decimal(value)
        case .i32(let value):
            return Decimal(value)
        case .u64(let value):
            return Decimal(value)
        case .i64(let value):
            return Decimal(value)
        case .u128(let parts):
            return combineU128(hi: parts.hi, lo: parts.lo)
        case .i128(let parts):
            return combineI128(hi: parts.hi, lo: parts.lo)
        default:
            return nil
        }
    }
    
    private func parsePoolStatus(_ scVal: SCVal) -> PoolStatus? {
        guard case .symbol(let status) = scVal else { return nil }
        
        switch status.lowercased() {
        case "active":
            return .active
        case "frozen":
            return .frozen
        case "paused":
            return .paused
        default:
            return nil
        }
    }
    
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
                position.asset = parseSCVal(entry.val) as? String ?? ""
            case "amount":
                if let value = parseDecimalValue(entry.val) {
                    position.amount = value
                }
            case "shares":
                if let value = parseDecimalValue(entry.val) {
                    position.shares = value
                }
            case "value":
                if let value = parseDecimalValue(entry.val) {
                    position.value = value
                }
            default:
                break
            }
        }
        
        return position.asset.isEmpty ? nil : position
    }
    
    private func parseReserveConfiguration(_ scVal: SCVal) -> ReserveConfiguration? {
        guard case .map(let entries) = scVal else { return nil }
        
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
                if let value = parseDecimalValue(entry.val) {
                    config.ltv = value / 10000 // Convert from basis points
                }
            case "liquidation_threshold":
                if let value = parseDecimalValue(entry.val) {
                    config.liquidationThreshold = value / 10000
                }
            case "liquidation_bonus":
                if let value = parseDecimalValue(entry.val) {
                    config.liquidationBonus = value / 10000
                }
            case "reserve_factor":
                if let value = parseDecimalValue(entry.val) {
                    config.reserveFactor = value / 10000
                }
            case "is_active":
                config.isActive = parseSCVal(entry.val) as? Bool ?? true
            case "is_frozen":
                config.isFrozen = parseSCVal(entry.val) as? Bool ?? false
            case "borrowing_enabled":
                config.borrowingEnabled = parseSCVal(entry.val) as? Bool ?? true
            default:
                break
            }
        }
        
        return config
    }
}

// MARK: - Data Extension for Hex String
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}