//
//  BlendParser.swift
//  Blendv3
//
//  Parser service responsible for all data parsing, transformation, and validation
//

import Foundation
import Combine

// MARK: - Parser Error Types
enum ParserError: LocalizedError {
    case invalidData
    case missingRequiredField(String)
    case invalidFormat(String)
    case validationFailed(String)
    case transformationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data provided"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidFormat(let format):
            return "Invalid format: \(format)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .transformationFailed(let reason):
            return "Transformation failed: \(reason)"
        }
    }
}

// MARK: - Parser Protocol
protocol BlendParserProtocol {
    func parse<T: Decodable>(_ data: Data, type: T.Type) -> Result<T, ParserError>
    func parseJSON<T: Decodable>(_ json: [String: Any], type: T.Type) -> Result<T, ParserError>
    func transform<T, U>(_ input: T, using transformer: (T) throws -> U) -> Result<U, ParserError>
    func validate<T>(_ input: T, using validator: (T) -> Bool, errorMessage: String) -> Result<T, ParserError>
    func parseContractResponse(_ data: Data) -> Result<ContractResponse, ParserError>
    func parseOracleData(_ data: Data) -> Result<OracleData, ParserError>
}

// MARK: - Data Models
struct ContractResponse: Decodable {
    let transactionHash: String
    let blockNumber: Int
    let gasUsed: Int
    let status: Bool
    let logs: [ContractLog]?
    let output: String?
}

struct ContractLog: Decodable {
    let address: String
    let topics: [String]
    let data: String
}

struct OracleData: Decodable {
    let timestamp: Date
    let value: Double
    let source: String
    let confidence: Double
    let metadata: [String: String]?
}

// MARK: - Transformer Protocols
protocol DataTransformer {
    associatedtype Input
    associatedtype Output
    func transform(_ input: Input) throws -> Output
}

// MARK: - Validator Protocols
protocol DataValidator {
    associatedtype Input
    func validate(_ input: Input) -> ValidationResult
}

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
}

// MARK: - BlendParser Implementation
final class BlendParser: BlendParserProtocol {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init() {
        // Configure decoder
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            
            // Try ISO8601 first
            if let dateString = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // Try Unix timestamp
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }
        
        // Configure encoder
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    // MARK: - Generic Parsing
    func parse<T: Decodable>(_ data: Data, type: T.Type) -> Result<T, ParserError> {
        do {
            let decoded = try decoder.decode(type, from: data)
            return .success(decoded)
        } catch let decodingError as DecodingError {
            return .failure(handleDecodingError(decodingError))
        } catch {
            return .failure(.invalidData)
        }
    }
    
    func parseJSON<T: Decodable>(_ json: [String: Any], type: T.Type) -> Result<T, ParserError> {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            return parse(data, type: type)
        } catch {
            return .failure(.invalidFormat("Unable to serialize JSON"))
        }
    }
    
    // MARK: - Transformation
    func transform<T, U>(_ input: T, using transformer: (T) throws -> U) -> Result<U, ParserError> {
        do {
            let output = try transformer(input)
            return .success(output)
        } catch {
            return .failure(.transformationFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Validation
    func validate<T>(_ input: T, using validator: (T) -> Bool, errorMessage: String) -> Result<T, ParserError> {
        if validator(input) {
            return .success(input)
        } else {
            return .failure(.validationFailed(errorMessage))
        }
    }
    
    // MARK: - Specialized Parsing
    func parseContractResponse(_ data: Data) -> Result<ContractResponse, ParserError> {
        let result = parse(data, type: ContractResponse.self)
        
        // Additional validation for contract responses
        switch result {
        case .success(let response):
            return validate(response, using: { response in
                !response.transactionHash.isEmpty &&
                response.blockNumber > 0 &&
                response.gasUsed >= 0
            }, errorMessage: "Invalid contract response format")
            
        case .failure:
            return result
        }
    }
    
    func parseOracleData(_ data: Data) -> Result<OracleData, ParserError> {
        let result = parse(data, type: OracleData.self)
        
        // Additional validation for oracle data
        switch result {
        case .success(let oracleData):
            return validate(oracleData, using: { data in
                data.value >= 0 &&
                data.confidence >= 0 && data.confidence <= 1 &&
                !data.source.isEmpty
            }, errorMessage: "Invalid oracle data format")
            
        case .failure:
            return result
        }
    }
    
    // MARK: - Error Handling
    private func handleDecodingError(_ error: DecodingError) -> ParserError {
        switch error {
        case .keyNotFound(let key, _):
            return .missingRequiredField(key.stringValue)
        case .typeMismatch(_, let context):
            return .invalidFormat(context.debugDescription)
        case .valueNotFound(_, let context):
            return .missingRequiredField(context.debugDescription)
        case .dataCorrupted(let context):
            return .invalidData
        @unknown default:
            return .invalidData
        }
    }
}

// MARK: - Common Transformers
struct HexToDecimalTransformer: DataTransformer {
    func transform(_ input: String) throws -> Int {
        guard input.hasPrefix("0x") else {
            throw ParserError.invalidFormat("Hex string must start with 0x")
        }
        
        let hex = String(input.dropFirst(2))
        guard let decimal = Int(hex, radix: 16) else {
            throw ParserError.transformationFailed("Invalid hex string")
        }
        
        return decimal
    }
}

struct WeiToEtherTransformer: DataTransformer {
    func transform(_ input: String) throws -> Double {
        guard let weiValue = Double(input) else {
            throw ParserError.transformationFailed("Invalid Wei value")
        }
        
        return weiValue / 1e18 // Convert Wei to Ether
    }
}

// MARK: - Common Validators
struct AddressValidator: DataValidator {
    func validate(_ input: String) -> ValidationResult {
        let isValid = input.hasPrefix("0x") && input.count == 42
        return ValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Invalid Ethereum address format"]
        )
    }
}

struct TransactionHashValidator: DataValidator {
    func validate(_ input: String) -> ValidationResult {
        let isValid = input.hasPrefix("0x") && input.count == 66
        return ValidationResult(
            isValid: isValid,
            errors: isValid ? [] : ["Invalid transaction hash format"]
        )
    }
}

// MARK: - Parser Extensions
extension BlendParser {
    // Batch parsing for multiple items
    func parseBatch<T: Decodable>(_ dataArray: [Data], type: T.Type) -> [Result<T, ParserError>] {
        return dataArray.map { parse($0, type: type) }
    }
    
    // Parse with custom transformation
    func parseAndTransform<T: Decodable, U>(
        _ data: Data,
        type: T.Type,
        transformer: (T) throws -> U
    ) -> Result<U, ParserError> {
        switch parse(data, type: type) {
        case .success(let parsed):
            return transform(parsed, using: transformer)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // Parse with validation
    func parseAndValidate<T: Decodable>(
        _ data: Data,
        type: T.Type,
        validator: (T) -> Bool,
        errorMessage: String
    ) -> Result<T, ParserError> {
        switch parse(data, type: type) {
        case .success(let parsed):
            return validate(parsed, using: validator, errorMessage: errorMessage)
        case .failure(let error):
            return .failure(error)
        }
    }
}