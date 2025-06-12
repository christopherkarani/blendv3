//
//  BlendParser.swift
//  Blendv3
//
//  Created by Chris Karani on 30/05/2025.
//

//import Foundation
//import stellarsdk
//
//extension BlendParser {
//    // Helper to convert Int128PartsXDR to Decimal
//    static  func parseI128ToDecimal(_ value: Int128PartsXDR) -> Decimal {
//        // Convert i128 to a single 128-bit integer value
//        let fullValue: Decimal
//        if value.hi == 0 {
//            // Simple case: only low 64 bits are used
//            fullValue = Decimal(value.lo)
//        } else if value.hi == -1 && (value.lo & 0x8000000000000000) != 0 {
//            // Negative number in two's complement
//            let signedLo = Int64(bitPattern: value.lo)
//            fullValue = Decimal(signedLo)
//        } else {
//            // Large positive number: combine hi and lo parts
//            // hi represents the upper 64 bits, lo represents the lower 64 bits
//            let hiDecimal = Decimal(value.hi) * Decimal(sign: .plus, exponent: 64, significand: 1)
//            let loDecimal = Decimal(value.lo)
//            fullValue = hiDecimal + loDecimal
//        }
//        // The value from the oracle is in fixed-point format with 7 decimals
//        // So we need to return the raw value as-is (it's already scaled)
//        return fullValue
//    }
//}
//import Foundation
//
//// MARK: - Parsing Errors
//enum ParsingError: Error, LocalizedError {
//    case invalidData
//    case missingRequiredField(String)
//    case unsupportedType(String)
//    case decodingError(Error)
//    case scvalXDRError(String)
//    case invalidFormat(String)
//    
//    var errorDescription: String? {
//        switch self {
//        case .invalidData:
//            return "Invalid data provided for parsing"
//        case .missingRequiredField(let field):
//            return "Missing required field: \(field)"
//        case .unsupportedType(let type):
//            return "Unsupported type: \(type)"
//        case .decodingError(let error):
//            return "Decoding error: \(error.localizedDescription)"
//        case .scvalXDRError(let message):
//            return "SCVal XDR parsing error: \(message)"
//        case .invalidFormat(let format):
//            return "Invalid format: \(format)"
//        }
//    }
//}
//
//// MARK: - SCVal XDR Types
//enum SCValType: String, CaseIterable {
//    case bool = "SCV_BOOL"
//    case void = "SCV_VOID"
//    case u32 = "SCV_U32"
//    case i32 = "SCV_I32"
//    case u64 = "SCV_U64"
//    case i64 = "SCV_I64"
//    case u128 = "SCV_U128"
//    case i128 = "SCV_I128"
//    case u256 = "SCV_U256"
//    case i256 = "SCV_I256"
//    case bytes = "SCV_BYTES"
//    case string = "SCV_STRING"
//    case symbol = "SCV_SYMBOL"
//    case vec = "SCV_VEC"
//    case map = "SCV_MAP"
//    case address = "SCV_ADDRESS"
//    case contractInstance = "SCV_CONTRACT_INSTANCE"
//    case ledgerKeyContractInstance = "SCV_LEDGER_KEY_CONTRACT_INSTANCE"
//    case ledgerKeyNonce = "SCV_LEDGER_KEY_NONCE"
//}
//
//// MARK: - SCVal Structure
//struct SCVal {
//    let type: SCValType
//    let value: Any?
//    
//    init(type: SCValType, value: Any? = nil) {
//        self.type = type
//        self.value = value
//    }
//}
//
//// MARK: - Contract Response Models
//struct ContractResponse {
//    let result: SCVal?
//    let status: String
//    let transactionHash: String?
//    let ledgerSequence: UInt64?
//    let events: [ContractEvent]
//    
//    init(result: SCVal? = nil, status: String, transactionHash: String? = nil, ledgerSequence: UInt64? = nil, events: [ContractEvent] = []) {
//        self.result = result
//        self.status = status
//        self.transactionHash = transactionHash
//        self.ledgerSequence = ledgerSequence
//        self.events = events
//    }
//}
//
//struct ContractEvent {
//    let type: String
//    let data: SCVal
//    let topics: [SCVal]
//    
//    init(type: String, data: SCVal, topics: [SCVal] = []) {
//        self.type = type
//        self.data = data
//        self.topics = topics
//    }
//}
//
//// MARK: - Parser Protocol
//protocol BlendParserProtocol {
//    func parseContractResponse(from data: Data) throws -> ContractResponse
//    func parseSCValXDR(from xdrString: String) throws -> SCVal
//    func parseSCValFromJSON(from json: [String: Any]) throws -> SCVal
//    func convertSCValToSwift(_ scval: SCVal) throws -> Any
//    func parseContractEvents(from data: Data) throws -> [ContractEvent]
//}
//
//// MARK: - Blend Parser Implementation
//struct BlendParser: BlendParserProtocol {
//    
//    // MARK: - Contract Response Parsing
//    func parseContractResponse(from data: Data) throws -> ContractResponse {
//        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
//            throw ParsingError.invalidData
//        }
//        
//        let status = json["status"] as? String ?? "unknown"
//        let transactionHash = json["transaction_hash"] as? String
//        let ledgerSequence = json["ledger_sequence"] as? UInt64
//        
//        var result: SCVal?
//        if let resultData = json["result"] as? [String: Any] {
//            result = try parseSCValFromJSON(from: resultData)
//        }
//        
//        var events: [ContractEvent] = []
//        if let eventsArray = json["events"] as? [[String: Any]] {
//            events = try eventsArray.map { eventData in
//                try parseContractEvent(from: eventData)
//            }
//        }
//        
//        return ContractResponse(
//            result: result,
//            status: status,
//            transactionHash: transactionHash,
//            ledgerSequence: ledgerSequence,
//            events: events
//        )
//    }
//    
//    // MARK: - SCVal XDR Parsing
//    func parseSCValXDR(from xdrString: String) throws -> SCVal {
//        // Remove any whitespace and validate format
//        let cleanXDR = xdrString.trimmingCharacters(in: .whitespacesAndNewlines)
//        
//        guard !cleanXDR.isEmpty else {
//            throw ParsingError.scvalXDRError("Empty XDR string")
//        }
//        
//        // Basic XDR parsing - in a real implementation, this would use proper XDR decoding
//        // For now, we'll implement a simplified parser that handles common cases
//        
//        // Try to decode as base64 first
//        guard let xdrData = Data(base64Encoded: cleanXDR) else {
//            throw ParsingError.scvalXDRError("Invalid base64 XDR encoding")
//        }
//        
//        return try parseSCValFromXDRData(xdrData)
//    }
//    
//    private func parseSCValFromXDRData(_ data: Data) throws -> SCVal {
//        // Simplified XDR parsing implementation
//        // In a real implementation, this would use proper XDR decoding libraries
//        
//        guard data.count >= 4 else {
//            throw ParsingError.scvalXDRError("XDR data too short")
//        }
//        
//        // Read the discriminant (first 4 bytes, big-endian)
//        let discriminant = data.withUnsafeBytes { bytes in
//            bytes.load(fromByteOffset: 0, as: UInt32.self).bigEndian
//        }
//        
//        // Map discriminant to SCVal type and parse value
//        switch discriminant {
//        case 0: // SCV_BOOL
//            if data.count >= 8 {
//                let boolValue = data.withUnsafeBytes { bytes in
//                    bytes.load(fromByteOffset: 4, as: UInt32.self).bigEndian != 0
//                }
//                return SCVal(type: .bool, value: boolValue)
//            }
//            
//        case 1: // SCV_VOID
//            return SCVal(type: .void)
//            
//        case 2: // SCV_U32
//            if data.count >= 8 {
//                let uint32Value = data.withUnsafeBytes { bytes in
//                    bytes.load(fromByteOffset: 4, as: UInt32.self).bigEndian
//                }
//                return SCVal(type: .u32, value: uint32Value)
//            }
//            
//        case 3: // SCV_I32
//            if data.count >= 8 {
//                let int32Value = data.withUnsafeBytes { bytes in
//                    Int32(bitPattern: bytes.load(fromByteOffset: 4, as: UInt32.self).bigEndian)
//                }
//                return SCVal(type: .i32, value: int32Value)
//            }
//            
//        case 6: // SCV_U64
//            if data.count >= 12 {
//                let uint64Value = data.withUnsafeBytes { bytes in
//                    bytes.load(fromByteOffset: 4, as: UInt64.self).bigEndian
//                }
//                return SCVal(type: .u64, value: uint64Value)
//            }
//            
//        case 7: // SCV_I64
//            if data.count >= 12 {
//                let int64Value = data.withUnsafeBytes { bytes in
//                    Int64(bitPattern: bytes.load(fromByteOffset: 4, as: UInt64.self).bigEndian)
//                }
//                return SCVal(type: .i64, value: int64Value)
//            }
//            
//        case 10: // SCV_BYTES
//            if data.count >= 8 {
//                let length = Int(data.withUnsafeBytes { bytes in
//                    bytes.load(fromByteOffset: 4, as: UInt32.self).bigEndian
//                })
//                
//                if data.count >= 8 + length {
//                    let bytesValue = data.subdata(in: 8..<(8 + length))
//                    return SCVal(type: .bytes, value: bytesValue)
//                }
//            }
//            
//        case 11: // SCV_STRING
//            if data.count >= 8 {
//                let length = Int(data.withUnsafeBytes { bytes in
//                    bytes.load(fromByteOffset: 4, as: UInt32.self).bigEndian
//                })
//                
//                if data.count >= 8 + length {
//                    let stringData = data.subdata(in: 8..<(8 + length))
//                    if let stringValue = String(data: stringData, encoding: .utf8) {
//                        return SCVal(type: .string, value: stringValue)
//                    }
//                }
//            }
//            
//        case 12: // SCV_SYMBOL
//            if data.count >= 8 {
//                let length = Int(data.withUnsafeBytes { bytes in
//                    bytes.load(fromByteOffset: 4, as: UInt32.self).bigEndian
//                })
//                
//                if data.count >= 8 + length {
//                    let symbolData = data.subdata(in: 8..<(8 + length))
//                    if let symbolValue = String(data: symbolData, encoding: .utf8) {
//                        return SCVal(type: .symbol, value: symbolValue)
//                    }
//                }
//            }
//            
//        default:
//            throw ParsingError.scvalXDRError("Unsupported SCVal discriminant: \(discriminant)")
//        }
//        
//        throw ParsingError.scvalXDRError("Failed to parse XDR data")
//    }
//    
//    // MARK: - JSON to SCVal Parsing
//    func parseSCValFromJSON(from json: [String: Any]) throws -> SCVal {
//        guard let typeString = json["type"] as? String,
//              let scvalType = SCValType(rawValue: typeString) else {
//            throw ParsingError.missingRequiredField("type")
//        }
//        
//        switch scvalType {
//        case .bool:
//            guard let value = json["value"] as? Bool else {
//                throw ParsingError.invalidFormat("Expected Bool for SCV_BOOL")
//            }
//            return SCVal(type: .bool, value: value)
//            
//        case .void:
//            return SCVal(type: .void)
//            
//        case .u32:
//            guard let value = json["value"] as? UInt32 else {
//                throw ParsingError.invalidFormat("Expected UInt32 for SCV_U32")
//            }
//            return SCVal(type: .u32, value: value)
//            
//        case .i32:
//            guard let value = json["value"] as? Int32 else {
//                throw ParsingError.invalidFormat("Expected Int32 for SCV_I32")
//            }
//            return SCVal(type: .i32, value: value)
//            
//        case .u64:
//            guard let value = json["value"] as? UInt64 else {
//                throw ParsingError.invalidFormat("Expected UInt64 for SCV_U64")
//            }
//            return SCVal(type: .u64, value: value)
//            
//        case .i64:
//            guard let value = json["value"] as? Int64 else {
//                throw ParsingError.invalidFormat("Expected Int64 for SCV_I64")
//            }
//            return SCVal(type: .i64, value: value)
//            
//        case .bytes:
//            guard let base64String = json["value"] as? String,
//                  let data = Data(base64Encoded: base64String) else {
//                throw ParsingError.invalidFormat("Expected base64 string for SCV_BYTES")
//            }
//            return SCVal(type: .bytes, value: data)
//            
//        case .string:
//            guard let value = json["value"] as? String else {
//                throw ParsingError.invalidFormat("Expected String for SCV_STRING")
//            }
//            return SCVal(type: .string, value: value)
//            
//        case .symbol:
//            guard let value = json["value"] as? String else {
//                throw ParsingError.invalidFormat("Expected String for SCV_SYMBOL")
//            }
//            return SCVal(type: .symbol, value: value)
//            
//        case .vec:
//            guard let arrayValue = json["value"] as? [[String: Any]] else {
//                throw ParsingError.invalidFormat("Expected Array for SCV_VEC")
//            }
//            let parsedArray = try arrayValue.map { try parseSCValFromJSON(from: $0) }
//            return SCVal(type: .vec, value: parsedArray)
//            
//        case .map:
//            guard let mapValue = json["value"] as? [[String: Any]] else {
//                throw ParsingError.invalidFormat("Expected Array of key-value pairs for SCV_MAP")
//            }
//            let parsedMap = try mapValue.compactMap { entry -> (SCVal, SCVal)? in
//                guard let keyData = entry["key"] as? [String: Any],
//                      let valueData = entry["value"] as? [String: Any] else {
//                    return nil
//                }
//                let key = try parseSCValFromJSON(from: keyData)
//                let value = try parseSCValFromJSON(from: valueData)
//                return (key, value)
//            }
//            return SCVal(type: .map, value: parsedMap)
//            
//        case .address:
//            guard let value = json["value"] as? String else {
//                throw ParsingError.invalidFormat("Expected String for SCV_ADDRESS")
//            }
//            return SCVal(type: .address, value: value)
//            
//        default:
//            throw ParsingError.unsupportedType(typeString)
//        }
//    }
//    
//    // MARK: - SCVal to Swift Conversion
//    func convertSCValToSwift(_ scval: SCVal) throws -> Any {
//        switch scval.type {
//        case .bool:
//            guard let value = scval.value as? Bool else {
//                throw ParsingError.invalidFormat("Invalid Bool value in SCVal")
//            }
//            return value
//            
//        case .void:
//            return NSNull()
//            
//        case .u32:
//            guard let value = scval.value as? UInt32 else {
//                throw ParsingError.invalidFormat("Invalid UInt32 value in SCVal")
//            }
//            return value
//            
//        case .i32:
//            guard let value = scval.value as? Int32 else {
//                throw ParsingError.invalidFormat("Invalid Int32 value in SCVal")
//            }
//            return value
//            
//        case .u64:
//            guard let value = scval.value as? UInt64 else {
//                throw ParsingError.invalidFormat("Invalid UInt64 value in SCVal")
//            }
//            return value
//            
//        case .i64:
//            guard let value = scval.value as? Int64 else {
//                throw ParsingError.invalidFormat("Invalid Int64 value in SCVal")
//            }
//            return value
//            
//        case .bytes:
//            guard let value = scval.value as? Data else {
//                throw ParsingError.invalidFormat("Invalid Data value in SCVal")
//            }
//            return value
//            
//        case .string, .symbol:
//            guard let value = scval.value as? String else {
//                throw ParsingError.invalidFormat("Invalid String value in SCVal")
//            }
//            return value
//            
//        case .address:
//            guard let value = scval.value as? String else {
//                throw ParsingError.invalidFormat("Invalid Address value in SCVal")
//            }
//            return value
//            
//        case .vec:
//            guard let array = scval.value as? [SCVal] else {
//                throw ParsingError.invalidFormat("Invalid Array value in SCVal")
//            }
//            return try array.map { try convertSCValToSwift($0) }
//            
//        case .map:
//            guard let mapArray = scval.value as? [(SCVal, SCVal)] else {
//                throw ParsingError.invalidFormat("Invalid Map value in SCVal")
//            }
//            var dictionary: [String: Any] = [:]
//            for (key, value) in mapArray {
//                let swiftKey = try convertSCValToSwift(key)
//                let swiftValue = try convertSCValToSwift(value)
//                dictionary[String(describing: swiftKey)] = swiftValue
//            }
//            return dictionary
//            
//        default:
//            throw ParsingError.unsupportedType(scval.type.rawValue)
//        }
//    }
//    
//    // MARK: - Contract Events Parsing
//    func parseContractEvents(from data: Data) throws -> [ContractEvent] {
//        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//              let eventsArray = json["events"] as? [[String: Any]] else {
//            throw ParsingError.invalidData
//        }
//        
//        return try eventsArray.map { eventData in
//            try parseContractEvent(from: eventData)
//        }
//    }
//    
//    private func parseContractEvent(from json: [String: Any]) throws -> ContractEvent {
//        guard let type = json["type"] as? String else {
//            throw ParsingError.missingRequiredField("type")
//        }
//        
//        guard let dataDict = json["data"] as? [String: Any] else {
//            throw ParsingError.missingRequiredField("data")
//        }
//        
//        let data = try parseSCValFromJSON(from: dataDict)
//        
//        var topics: [SCVal] = []
//        if let topicsArray = json["topics"] as? [[String: Any]] {
//            topics = try topicsArray.map { topicData in
//                try parseSCValFromJSON(from: topicData)
//            }
//        }
//        
//        return ContractEvent(type: type, data: data, topics: topics)
//    }
//}
//
//// MARK: - Convenience Extensions
//extension SCVal: CustomStringConvertible {
//    var description: String {
//        return "SCVal(type: \(type.rawValue), value: \(value ?? "nil"))"
//    }
//}
//
//extension ContractResponse: CustomStringConvertible {
//    var description: String {
//        return "ContractResponse(status: \(status), result: \(result?.description ?? "nil"), events: \(events.count))"
//    }
//}
