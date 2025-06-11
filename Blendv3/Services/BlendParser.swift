import Foundation
import stellarsdk

/// Core parsing service for Soroban contract responses and data
/// Handles XDR decoding, SCVal parsing, and data type conversions
class BlendParser {
    
    // MARK: - Singleton
    
    static let shared = BlendParser()
    
    private init() {}
    
    // MARK: - SCVal Parsing
    
    /// Parse SCVal to String
    func parseString(from scVal: SCVal) throws -> String {
        switch scVal {
        case .string(let value):
            return value
        case .symbol(let value):
            return value
        default:
            throw ParseError.invalidType("Expected string or symbol, got \(scVal)")
        }
    }
    
    /// Parse SCVal to UInt64
    func parseUInt64(from scVal: SCVal) throws -> UInt64 {
        switch scVal {
        case .u64(let value):
            return value
        case .i64(let value):
            if value >= 0 {
                return UInt64(value)
            } else {
                throw ParseError.invalidValue("Cannot convert negative i64 to UInt64")
            }
        case .u32(let value):
            return UInt64(value)
        case .i32(let value):
            if value >= 0 {
                return UInt64(value)
            } else {
                throw ParseError.invalidValue("Cannot convert negative i32 to UInt64")
            }
        default:
            throw ParseError.invalidType("Expected numeric type, got \(scVal)")
        }
    }
    
    /// Parse SCVal to Int64
    func parseInt64(from scVal: SCVal) throws -> Int64 {
        switch scVal {
        case .i64(let value):
            return value
        case .u64(let value):
            if value <= Int64.max {
                return Int64(value)
            } else {
                throw ParseError.overflow("UInt64 value too large for Int64")
            }
        case .i32(let value):
            return Int64(value)
        case .u32(let value):
            return Int64(value)
        default:
            throw ParseError.invalidType("Expected numeric type, got \(scVal)")
        }
    }
    
    /// Parse SCVal to UInt32
    func parseUInt32(from scVal: SCVal) throws -> UInt32 {
        switch scVal {
        case .u32(let value):
            return value
        case .i32(let value):
            if value >= 0 {
                return UInt32(value)
            } else {
                throw ParseError.invalidValue("Cannot convert negative i32 to UInt32")
            }
        case .u64(let value):
            if value <= UInt32.max {
                return UInt32(value)
            } else {
                throw ParseError.overflow("UInt64 value too large for UInt32")
            }
        case .i64(let value):
            if value >= 0 && value <= UInt32.max {
                return UInt32(value)
            } else {
                throw ParseError.overflow("Int64 value out of range for UInt32")
            }
        default:
            throw ParseError.invalidType("Expected numeric type, got \(scVal)")
        }
    }
    
    /// Parse SCVal to Boolean
    func parseBool(from scVal: SCVal) throws -> Bool {
        switch scVal {
        case .bool(let value):
            return value
        default:
            throw ParseError.invalidType("Expected boolean, got \(scVal)")
        }
    }
    
    /// Parse SCVal to Address (Contract or Account)
    func parseAddress(from scVal: SCVal) throws -> String {
        switch scVal {
        case .address(let address):
            switch address {
            case .account(let accountId):
                return accountId.accountId
            case .contract(let contractId):
                return contractId.wrapped.hexEncodedString()
            }
        default:
            throw ParseError.invalidType("Expected address, got \(scVal)")
        }
    }
    
    /// Parse SCVal to bytes
    func parseBytes(from scVal: SCVal) throws -> Data {
        switch scVal {
        case .bytes(let data):
            return data
        default:
            throw ParseError.invalidType("Expected bytes, got \(scVal)")
        }
    }
    
    /// Parse SCVal array to [SCVal]
    func parseArray(from scVal: SCVal) throws -> [SCVal] {
        switch scVal {
        case .vec(let values):
            return values ?? []
        default:
            throw ParseError.invalidType("Expected array, got \(scVal)")
        }
    }
    
    /// Parse SCVal map to [String: SCVal]
    func parseMap(from scVal: SCVal) throws -> [String: SCVal] {
        switch scVal {
        case .map(let mapEntries):
            var result: [String: SCVal] = [:]
            for entry in mapEntries ?? [] {
                let key = try parseString(from: entry.key)
                result[key] = entry.val
            }
            return result
        default:
            throw ParseError.invalidType("Expected map, got \(scVal)")
        }
    }
    
    /// Parse SCVal to optional value
    func parseOptional<T>(from scVal: SCVal, using parser: (SCVal) throws -> T) throws -> T? {
        switch scVal {
        case .instanceU32(let instance):
            // Stellar uses instance for Option types
            if instance.instanceType == 0 { // None
                return nil
            } else { // Some
                // The actual value would be in a nested structure
                throw ParseError.notImplemented("Complex optional parsing not implemented")
            }
        case .void:
            return nil
        default:
            // Direct value
            return try parser(scVal)
        }
    }
    
    // MARK: - Contract Data Parsing
    
    /// Parse contract data from LedgerEntryResult
    func parseContractData(from entry: LedgerEntryResult) throws -> SCVal {
        guard let contractData = entry.contractData else {
            throw ParseError.invalidStructure("No contract data in entry")
        }
        return contractData.val
    }
    
    /// Parse contract data to specific type
    func parseContractData<T>(from entry: LedgerEntryResult, using parser: (SCVal) throws -> T) throws -> T {
        let scVal = try parseContractData(from: entry)
        return try parser(scVal)
    }
    
    // MARK: - Transaction Result Parsing
    
    /// Parse transaction result for contract invoke operations
    func parseTransactionResult(from response: SubmitTransactionResponse) throws -> [SCVal] {
        guard response.status == .success else {
            throw ParseError.transactionFailed("Transaction failed with status: \(response.status)")
        }
        
        guard let resultXdr = response.resultXdr else {
            throw ParseError.missingData("No result XDR in response")
        }
        
        let transactionResult = try TransactionResultXDR(xdr: resultXdr)
        
        switch transactionResult.result {
        case .success(let results):
            var scVals: [SCVal] = []
            
            for result in results {
                if case .invokeContract(let invokeResult) = result.operationResult {
                    switch invokeResult {
                    case .success(let scVal):
                        scVals.append(scVal)
                    case .malformed, .underfunded, .resourceLimitExceeded:
                        throw ParseError.operationFailed("Invoke contract operation failed")
                    }
                }
            }
            
            return scVals
        case .failed, .tooEarly, .tooLate, .missingOperation, .badSequence, .badAuth, .insufficientBalance, .noAccount, .insufficientFee, .badAuthExtra, .internalError, .notSupported, .feeBoost, .badSponsorship, .badMinSeqnumAge, .malformed:
            throw ParseError.transactionFailed("Transaction failed: \(transactionResult.result)")
        }
    }
    
    /// Parse single result from transaction
    func parseSingleResult(from response: SubmitTransactionResponse) throws -> SCVal {
        let results = try parseTransactionResult(from: response)
        guard let result = results.first else {
            throw ParseError.missingData("No operation results found")
        }
        return result
    }
    
    // MARK: - Event Parsing
    
    /// Parse contract events from GetEventsResponse
    func parseEvents(from response: GetEventsResponse) -> [ContractEvent] {
        return response.events.compactMap { eventInfo in
            guard let event = eventInfo.event else { return nil }
            return event
        }
    }
    
    /// Parse event topics as strings
    func parseEventTopics(from event: ContractEvent) throws -> [String] {
        return try event.topics.map { topic in
            try parseString(from: topic)
        }
    }
    
    /// Parse event data
    func parseEventData<T>(from event: ContractEvent, using parser: (SCVal) throws -> T) throws -> T {
        return try parser(event.data)
    }
    
    // MARK: - Utility Methods
    
    /// Safe parsing with default value
    func parseWithDefault<T>(
        from scVal: SCVal,
        using parser: (SCVal) throws -> T,
        default defaultValue: T
    ) -> T {
        do {
            return try parser(scVal)
        } catch {
            return defaultValue
        }
    }
    
    /// Parse array of values
    func parseArrayOfValues<T>(
        from scVal: SCVal,
        using parser: (SCVal) throws -> T
    ) throws -> [T] {
        let array = try parseArray(from: scVal)
        return try array.map(parser)
    }
    
    /// Create SCVal primitives for contract calls
    func createSCVal(from value: Any) throws -> SCVal {
        switch value {
        case let stringValue as String:
            return .string(stringValue)
        case let intValue as Int:
            return .i64(Int64(intValue))
        case let int32Value as Int32:
            return .i32(int32Value)
        case let int64Value as Int64:
            return .i64(int64Value)
        case let uint32Value as UInt32:
            return .u32(uint32Value)
        case let uint64Value as UInt64:
            return .u64(uint64Value)
        case let boolValue as Bool:
            return .bool(boolValue)
        case let dataValue as Data:
            return .bytes(dataValue)
        case let arrayValue as [Any]:
            let scVals = try arrayValue.map { try createSCVal(from: $0) }
            return .vec(scVals)
        default:
            throw ParseError.unsupportedType("Cannot convert \(type(of: value)) to SCVal")
        }
    }
    
    /// Create address SCVal from string
    func createAddressSCVal(from address: String) throws -> SCVal {
        if address.hasPrefix("C") {
            // Contract address
            let contractId = try ContractIdXDR(contractId: address)
            return .address(.contract(contractId))
        } else if address.hasPrefix("G") {
            // Account address
            let accountId = try PublicKey(accountId: address)
            return .address(.account(accountId))
        } else {
            throw ParseError.invalidAddress("Invalid address format: \(address)")
        }
    }
}

// MARK: - Error Types

enum ParseError: Error, LocalizedError {
    case invalidType(String)
    case invalidValue(String)
    case invalidAddress(String)
    case invalidStructure(String)
    case overflow(String)
    case missingData(String)
    case transactionFailed(String)
    case operationFailed(String)
    case unsupportedType(String)
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidType(let message):
            return "Invalid type: \(message)"
        case .invalidValue(let message):
            return "Invalid value: \(message)"
        case .invalidAddress(let message):
            return "Invalid address: \(message)"
        case .invalidStructure(let message):
            return "Invalid structure: \(message)"
        case .overflow(let message):
            return "Overflow: \(message)"
        case .missingData(let message):
            return "Missing data: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .unsupportedType(let message):
            return "Unsupported type: \(message)"
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        }
    }
}