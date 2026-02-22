import Foundation
import stellarsdk

// MARK: - Parsing Extensions (Migrated to BlendParser)

extension BackstopContractService {
    
    // MARK: - Migration Notice
    
    /*
     * All parsing functions have been migrated to BlendParser for centralized parsing logic.
     * 
     * Migrated Functions:
     * - parseI128Response(_:) -> BlendParser.parseI128Response(_:)
     * - parseAddressResponse(_:) -> BlendParser.parseAddressResponse(_:)
     * - parseQ4WResponse(_:) -> BlendParser.parseQ4WResponse(_:)
     * - parseUserBalanceResponse(_:) -> BlendParser.parseUserBalanceResponse(_:)
     * - parsePoolBackstopDataResponse(_:) -> BlendParser.parsePoolBackstopDataResponse(_:)
     * - parseBackstopEmissionsDataResponse(_:) -> BlendParser.parseBackstopEmissionsDataResponse(_:)
     * - parseUserEmissionDataResponse(_:) -> BlendParser.parseUserEmissionDataResponse(_:)
     * - parseTokenValueTupleResponse(_:) -> BlendParser.parseTokenValueTupleResponse(_:)
     * 
     * Usage Pattern:
     * Before: let result = parseUserBalanceResponse(response)
     * After:  let result = blendParser.parseUserBalanceResponse(response)
     * 
     * The BlendParser instance is available as `self.blendParser` in all BackstopContractService methods.
     */
    
    // MARK: - Convenience Methods (Optional)
    
    /// Convenience method for parsing emission data responses
    /// This demonstrates how service-specific parsing logic can still exist while delegating to BlendParser
    internal func parseEmissionDataResponse(_ response: SCValXDR) throws -> (BackstopEmissionsData, UserEmissionData) {
        // Example of how to combine multiple parsing operations
        // In practice, this would depend on the actual response structure
        let backstopData = try blendParser.parseBackstopEmissionsDataResponse(response)
        let userData = try blendParser.parseUserEmissionDataResponse(response)
        return (backstopData, userData)
    }
}

// MARK: - Error Handling Extensions

extension BackstopContractService {
    
    /// Convert BlendParsingError to BackstopError for consistent error handling
    internal func convertParsingError(_ error: Error, context: String) -> BackstopError {
        if let parsingError = error as? BlendParsingError {
            switch parsingError {
            case .invalidType(let expected, let actual):
                return BackstopError.parsingError(context, expectedType: expected, actualType: actual)
            case .missingRequiredField(let field):
                return BackstopError.parsingError(context, expectedType: "required field", actualType: "missing \(field)")
            case .invalidValue(let description):
                return BackstopError.parsingError(context, expectedType: "valid value", actualType: description)
            case .malformedResponse(let description):
                return BackstopError.parsingError(context, expectedType: "well-formed response", actualType: description)
            default:
                return BackstopError.parsingError(context, expectedType: "valid response", actualType: "parsing failed")
            }
        }
        return BackstopError.parsingError(context, expectedType: "valid response", actualType: error.localizedDescription)
    }
}
