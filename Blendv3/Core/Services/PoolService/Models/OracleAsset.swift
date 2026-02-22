//
//  OracleAsset.swift
//  Blendv3
//
//  Created by Chris Karani on 28/05/2025.
//

import Foundation
import stellarsdk

// MARK: - Data Extension for Hex Conversion

fileprivate extension Data {
    // Initialize Data from a hex string
    init?(hexString: String) {
        let hexStr = hexString.replacingOccurrences(of: " ", with: "")
        guard hexStr.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: hexStr.count / 2)
        var i = hexStr.startIndex
        
        while i < hexStr.endIndex {
            let j = hexStr.index(i, offsetBy: 2)
            if let byte = UInt8(hexStr[i..<j], radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            i = j
        }
        
        self = data
    }
    
    // Convert Data to hex string
    func stellarHexEncodedString() -> String { 
        map { String(format: "%02x", $0) }.joined() 
    }
}

/// Represents the Asset enum from the smart contract
/// Maps to the contract's Asset union type with Stellar(address) and Other(symbol) cases
public enum OracleAsset: Codable, Equatable, CustomStringConvertible {
    case stellar(address: String)
    case other(symbol: String)
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case type
        case address
        case symbol
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "stellar":
            let address = try container.decode(String.self, forKey: .address)
            self = .stellar(address: address)
        case "other":
            let symbol = try container.decode(String.self, forKey: .symbol)
            self = .other(symbol: symbol)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown asset type: \(type)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .stellar(let address):
            try container.encode("stellar", forKey: .type)
            try container.encode(address, forKey: .address)
        case .other(let symbol):
            try container.encode("other", forKey: .type)
            try container.encode(symbol, forKey: .symbol)
        }
    }
    
    // Additional Codable support - allows OracleAsset to be used with CacheService
    public static func decode(from data: Data) throws -> OracleAsset {
        let decoder = JSONDecoder()
        return try decoder.decode(OracleAsset.self, from: data)
    }
    
    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
    
    // MARK: - SCValXDR Conversion
    
    /// Convert OracleAsset to SCValXDR for contract calls
    public func toSCVal() -> SCValXDR {
        switch self {
        case .stellar(let address):
            // Format as Asset::Stellar(address)
            let discriminant = SCValXDR.symbol("Stellar")
            
            // Convert string address to SCAddressXDR
            let scAddress: SCAddressXDR
            if StellarContractID.isStrKeyContract(address), let hexString = try? StellarContractID.decode(strKey: address), let contractData = Data(hexString: hexString) {
                // Wrap the Data in WrappedData32 before passing to contract()
                scAddress = SCAddressXDR.contract(WrappedData32(contractData))
            } else {
                // Fallback - this should not happen with valid addresses
                // but preventing runtime crashes in case of invalid data
                scAddress = SCAddressXDR.contract(WrappedData32(Data(repeating: 0, count: 32)))
            }
            
            let addressVal = SCValXDR.address(scAddress)
            return SCValXDR.vec([discriminant, addressVal])
            
        case .other(let symbol):
            // Format as Asset::Other(symbol)
            let discriminant = SCValXDR.symbol("Other")
            let symbolVal = SCValXDR.symbol(symbol)
            return SCValXDR.vec([discriminant, symbolVal])
        }
    }
    
    /// Create OracleAsset from SCValXDR response
    public static func fromSCVal(_ val: SCValXDR) throws -> OracleAsset {
        guard case .vec(let valuesOptional) = val, let values = valuesOptional, values.count == 2 else {
            throw OracleError.invalidAssetFormat("Asset must be a vec with 2 elements")
        }
        
        guard case .symbol(let discriminant) = values[0] else {
            throw OracleError.invalidAssetFormat("First element must be a symbol discriminant")
        }
        
        switch discriminant {
        case "Stellar":
            guard case .address(let address) = values[1] else {
                throw OracleError.invalidAssetFormat("Stellar asset must have address as second element")
            }
            
            // Convert SCAddressXDR to string
            let addressString: String
            
            // Use the type() method to check SCAddressXDR type
            let addressType = address.type()
            
            switch addressType {
            case SCAddressType.account.rawValue:
                // For account type SCAddressXDR
                switch address {
                case .account(let publicKey):
                    // We need to handle account ID encoding differently since StellarContractID only handles contract addresses
                    // Use a placeholder implementation or throw an error since we're focusing on contract addresses
                    throw OracleError.invalidAssetFormat("Account addresses not currently supported")
                default:
                    throw OracleError.invalidAssetFormat("Invalid account address data")
                }
                
            case SCAddressType.contract.rawValue:
                // For contract type SCAddressXDR
                switch address {
                case .contract(let wrappedData):
                    // Extract Data from WrappedData32 and convert to hex string
                    let contractData = wrappedData.wrapped
                    let hexString = contractData.stellarHexEncodedString()
                    addressString = try StellarContractID.encode(hex: hexString)
                default:
                    throw OracleError.invalidAssetFormat("Invalid contract address data")
                }
                
            default:
                throw OracleError.invalidAssetFormat("Unknown address type: \(addressType)")
            }
            
            return .stellar(address: addressString)
            
        case "Other":
            guard case .symbol(let symbol) = values[1] else {
                throw OracleError.invalidAssetFormat("Other asset must have symbol as second element")
            }
            return .other(symbol: symbol)
            
        default:
            throw OracleError.invalidAssetFormat("Unknown asset discriminant: \(discriminant)")
        }
    }
    
    // MARK: - Utility Methods
    
    /// String representation for debugging and display
    public var description: String {
        switch self {
        case .stellar(let address):
            return "Stellar(\(address))"
        case .other(let symbol):
            return "Other(\(symbol))"
        }
    }
    
    /// Convert to an asset ID string for cache keys and lookups
    public var assetId: String {
        switch self {
        case .stellar(let address):
            return "\(address)"
        case .other(let symbol):
            return "other:\(symbol)"
        }
    }
    
    /// User-friendly display name
    public var displayName: String {
        switch self {
        case .stellar(let address):
            // For stellar assets, use a shortened address form
            let start = address.prefix(4)
            let end = address.suffix(4)
            return "Stellar Asset (\(start)...\(end))"
        case .other(let symbol):
            return symbol
        }
    }
}
