import Foundation
import stellarsdk

/// A comprehensive tool for inspecting Stellar/Soroban smart contracts
/// Provides functionality to retrieve WASM binary, list available functions,
/// and present contract data in human-readable format
public class SmartContractInspector {
    
    private let sorobanServer: SorobanServer
    private let network: Network
    
    // MARK: - Initialization
    
    /// Initialize the inspector with a Soroban RPC endpoint
    /// - Parameters:
    ///   - rpcEndpoint: The URL of the Soroban RPC server
    ///   - network: The Stellar network (testnet, mainnet, etc.)
    public init(rpcEndpoint: String, network: Network) {
        self.sorobanServer = SorobanServer(endpoint: rpcEndpoint)
        self.network = network
    }
    
    // MARK: - Contract Introspection
    
    /// Retrieves and inspects a smart contract by its contract ID
    /// - Parameter contractId: The contract ID on the Stellar network
    /// - Returns: A ContractInspectionResult containing all contract information
    public func inspectContract(contractId: String) async throws -> ContractInspectionResult {
        let startTime = Date()
        
        debugLog("Starting contract inspection", category: .contract, metadata: [
            "contractId": contractId
        ])
        
        // Retrieve contract info including WASM binary
        debugLog("Requesting contract info from RPC", category: .network, metadata: [
            "contractId": contractId
        ])
        
        let contractInfoResult = await sorobanServer.getContractInfoForContractId(contractId: contractId)
        
        switch contractInfoResult {
        case .success(let contractInfo):
            debugLog("Contract info retrieved successfully", category: .contract, metadata: [
                "contractId": contractId,
                "specEntries": contractInfo.specEntries.count,
                "metaEntries": contractInfo.metaEntries.count,
                "interfaceVersion": contractInfo.envInterfaceVersion
            ])
            
            do {
                let result = try processContractInfo(contractInfo, contractId: contractId)
                
                let duration = Date().timeIntervalSince(startTime)
                infoLog("Contract inspection completed successfully", category: .contract, metadata: [
                    "contractId": contractId,
                    "duration": String(format: "%.3f", duration),
                    "functionsCount": result.functions.count,
                    "customTypesCount": result.customTypes.structs.count + result.customTypes.enums.count
                ])
                
                return result
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                errorLog("Failed to process contract info", category: .parsing, metadata: [
                    "contractId": contractId,
                    "duration": String(format: "%.3f", duration),
                    "error": error.localizedDescription
                ])
                throw error
            }
            
        case .parsingFailure(let error):
            let duration = Date().timeIntervalSince(startTime)
            errorLog("Contract info parsing failed", category: .parsing, metadata: [
                "contractId": contractId,
                "duration": String(format: "%.3f", duration),
                "error": error.localizedDescription
            ])
            throw ContractInspectionError.parsingFailed(error.localizedDescription)
            
        case .rpcFailure(let error):
            let duration = Date().timeIntervalSince(startTime)
            errorLog("RPC request failed", category: .network, metadata: [
                "contractId": contractId,
                "duration": String(format: "%.3f", duration),
                "error": error.localizedDescription
            ])
            throw ContractInspectionError.rpcFailed(error.localizedDescription)
        }
    }
    
    /// Retrieves and inspects a smart contract by its WASM ID
    /// - Parameter wasmId: The WASM ID of the deployed contract code
    /// - Returns: A ContractInspectionResult containing all contract information
    public func inspectContractByWasmId(wasmId: String) async throws -> ContractInspectionResult {
        print("🔍 Inspecting contract by WASM ID: \(wasmId)")
        
        let contractInfoResult = await sorobanServer.getContractInfoForWasmId(wasmId: wasmId)
        
        switch contractInfoResult {
        case .success(let contractInfo):
            return try processContractInfo(contractInfo, wasmId: wasmId)
            
        case .parsingFailure(let error):
            throw ContractInspectionError.parsingFailed(error.localizedDescription)
            
        case .rpcFailure(let error):
            throw ContractInspectionError.rpcFailed(error.localizedDescription)
        }
    }
    
    /// Retrieves raw WASM binary for a contract
    /// - Parameter contractId: The contract ID
    /// - Returns: The raw WASM binary data
    public func getContractWasmBinary(contractId: String) async throws -> Data {
        let startTime = Date()
        
        debugLog("Requesting WASM binary", category: .wasm, metadata: [
            "contractId": contractId
        ])
        
        let result = await sorobanServer.getContractCodeForContractId(contractId: contractId)
        
        switch result {
        case .success(let contractCode):
            let duration = Date().timeIntervalSince(startTime)
            let wasmSize = contractCode.code.count
            
            infoLog("WASM binary retrieved successfully", category: .wasm, metadata: [
                "contractId": contractId,
                "duration": String(format: "%.3f", duration),
                "wasmSize": wasmSize,
                "sizeFormatted": ByteCountFormatter().string(fromByteCount: Int64(wasmSize))
            ])
            
            return contractCode.code
            
        case .failure(let error):
            let duration = Date().timeIntervalSince(startTime)
            errorLog("Failed to retrieve WASM binary", category: .wasm, metadata: [
                "contractId": contractId,
                "duration": String(format: "%.3f", duration),
                "error": error.localizedDescription
            ])
            throw ContractInspectionError.rpcFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Contract Data Retrieval
    
    /// Retrieves and formats contract data entries
    /// - Parameters:
    ///   - contractId: The contract ID
    ///   - key: The storage key to retrieve
    ///   - durability: The durability type (persistent or temporary)
    /// - Returns: Formatted contract data
    public func getContractData(
        contractId: String,
        key: SCValXDR,
        durability: ContractDataDurability = .persistent
    ) async throws -> ContractDataResult {
        let result = await sorobanServer.getContractData(
            contractId: contractId,
            key: key,
            durability: durability
        )
        
        switch result {
        case .success(let ledgerEntry):
            return try parseContractData(ledgerEntry)
            
        case .failure(let error):
            throw ContractInspectionError.rpcFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func processContractInfo(
        _ contractInfo: SorobanContractInfo,
        contractId: String? = nil,
        wasmId: String? = nil
    ) throws -> ContractInspectionResult {
        var functions: [ContractFunction] = []
        var customTypes: ContractCustomTypes = ContractCustomTypes()
        
        // Process contract spec entries
        for entry in contractInfo.specEntries {
            switch entry {
            case .functionV0(let function):
                functions.append(parseFunction(function))
                
            case .structV0(let structDef):
                customTypes.structs.append(parseStruct(structDef))
                
            case .unionV0(let unionDef):
                customTypes.unions.append(parseUnion(unionDef))
                
            case .enumV0(let enumDef):
                customTypes.enums.append(parseEnum(enumDef))
                
            case .errorEnumV0(let errorDef):
                customTypes.errors.append(parseError(errorDef))
            }
        }
        
        return ContractInspectionResult(
            contractId: contractId,
            wasmId: wasmId,
            interfaceVersion: contractInfo.envInterfaceVersion,
            functions: functions,
            customTypes: customTypes,
            metadata: contractInfo.metaEntries
        )
    }
    
    private func parseFunction(_ function: SCSpecFunctionV0XDR) -> ContractFunction {
        let inputs = function.inputs.map { input in
            FunctionParameter(
                name: input.name,
                type: formatType(input.type),
                doc: input.doc
            )
        }
        
        let outputs = function.outputs.map { output in
            formatType(output)
        }
        
        return ContractFunction(
            name: function.name,
            doc: function.doc,
            inputs: inputs,
            outputs: outputs
        )
    }
    
    private func parseStruct(_ structDef: SCSpecUDTStructV0XDR) -> ContractStruct {
        let fields = structDef.fields.map { field in
            StructField(
                name: field.name,
                type: formatType(field.type),
                doc: field.doc
            )
        }
        
        return ContractStruct(
            name: structDef.name,
            doc: structDef.doc,
            fields: fields
        )
    }
    
    private func parseUnion(_ unionDef: SCSpecUDTUnionV0XDR) -> ContractUnion {
        let cases = unionDef.cases.map { unionCase in
            switch unionCase {
            case .voidV0(let voidCase):
                return UnionCase(
                    kind: .voidV0,
                    name: voidCase.name,
                    type: nil,
                    doc: voidCase.doc
                )
            case .tupleV0(let tupleCase):
                let typeStrings = tupleCase.type.map { formatType($0) }.joined(separator: ", ")
                return UnionCase(
                    kind: .tupleV0,
                    name: tupleCase.name,
                    type: "tuple<\(typeStrings)>",
                    doc: tupleCase.doc
                )
            }
        }
        
        return ContractUnion(
            name: unionDef.name,
            doc: unionDef.doc,
            cases: cases
        )
    }
    
    private func parseEnum(_ enumDef: SCSpecUDTEnumV0XDR) -> ContractEnum {
        let cases = enumDef.cases.map { enumCase in
            EnumCase(
                name: enumCase.name,
                value: enumCase.value,
                doc: enumCase.doc
            )
        }
        
        return ContractEnum(
            name: enumDef.name,
            doc: enumDef.doc,
            cases: cases
        )
    }
    
    private func parseError(_ errorDef: SCSpecUDTErrorEnumV0XDR) -> ContractError {
        let cases = errorDef.cases.map { errorCase in
            ErrorCase(
                name: errorCase.name,
                value: errorCase.value,
                doc: errorCase.doc
            )
        }
        
        return ContractError(
            name: errorDef.name,
            doc: errorDef.doc,
            cases: cases
        )
    }
    
    private func formatType(_ type: SCSpecTypeDefXDR) -> String {
        switch type {
        case .bool:
            return "bool"
        case .void:
            return "void"
        case .error:
            return "error"
        case .u32:
            return "u32"
        case .i32:
            return "i32"
        case .u64:
            return "u64"
        case .i64:
            return "i64"
        case .timepoint:
            return "timepoint"
        case .duration:
            return "duration"
        case .u128:
            return "u128"
        case .i128:
            return "i128"
        case .u256:
            return "u256"
        case .i256:
            return "i256"
        case .bytes:
            return "bytes"
        case .string:
            return "string"
        case .symbol:
            return "symbol"
        case .address:
            return "address"
        case .option(let optionType):
            return "option<\(formatType(optionType.valueType))>"
        case .result(let resultType):
            return "result<\(formatType(resultType.okType)), \(formatType(resultType.errorType))>"
        case .vec(let vecType):
            return "vec<\(formatType(vecType.elementType))>"
        case .map(let mapType):
            return "map<\(formatType(mapType.keyType)), \(formatType(mapType.valueType))>"
        case .tuple(let tupleType):
            let types = tupleType.valueTypes.map { formatType($0) }.joined(separator: ", ")
            return "tuple<\(types)>"
        case .bytesN(let bytesN):
            return "bytesN<\(bytesN.n)>"
        case .udt(let udtType):
            return udtType.name
        case .val:
            return "val"
        }
    }
    
    private func parseContractData(_ ledgerEntry: LedgerEntry) throws -> ContractDataResult {
        guard let xdrData = try? LedgerEntryDataXDR(fromBase64: ledgerEntry.xdr) else {
            throw ContractInspectionError.parsingFailed("Failed to parse ledger entry XDR")
        }
        
        guard let contractData = xdrData.contractData else {
            throw ContractInspectionError.parsingFailed("Ledger entry is not contract data")
        }
        
        return ContractDataResult(
            key: formatSCVal(contractData.key),
            value: formatSCVal(contractData.val),
            durability: contractData.durability,
            lastModifiedLedger: ledgerEntry.lastModifiedLedgerSeq
        )
    }
    
    private func formatSCVal(_ val: SCValXDR) -> String {
        // Simplified formatting - expand based on your needs
        switch val {
        case .bool(let b):
            return b.description
        case .void:
            return "void"
        case .u32(let n):
            return n.description
        case .i32(let n):
            return n.description
        case .u64(let n):
            return n.description
        case .i64(let n):
            return n.description
        case .u128(let parts):
            return "u128(\(parts.hi):\(parts.lo))"
        case .i128(let parts):
            return "i128(\(parts.hi):\(parts.lo))"
        case .bytes(let data):
            return "bytes(\(data.hexEncodedString()))"
        case .string(let str):
            return "\"\(str)\""
        case .symbol(let sym):
            return "symbol(\(sym))"
        case .vec(let vec):
            let elements = vec?.map { formatSCVal($0) }.joined(separator: ", ") ?? ""
            return "[\(elements)]"
        case .map(let map):
            let entries = map?.map { "{\(formatSCVal($0.key)): \(formatSCVal($0.val))}" }.joined(separator: ", ") ?? ""
            return "{\(entries)}"
        case .address(let addr):
            return formatAddress(addr)
        case .error(let error):
            return "error(\(error))"
        case .timepoint(let tp):
            return "timepoint(\(tp))"
        case .duration(let dur):
            return "duration(\(dur))"
        case .u256(let parts):
            return "u256(\(parts.hiHi):\(parts.hiLo):\(parts.loHi):\(parts.loLo))"
        case .i256(let parts):
            return "i256(\(parts.hiHi):\(parts.hiLo):\(parts.loHi):\(parts.loLo))"
        case .ledgerKeyContractInstance:
            return "ledgerKeyContractInstance"
        case .contractInstance(let instance):
            return "contractInstance(\(instance))"
        case .ledgerKeyNonce(let nonce):
            return "ledgerKeyNonce(\(nonce.nonce))"
        }
    }
    
    private func formatAddress(_ address: SCAddressXDR) -> String {
        switch address {
        case .account(let accountId):
            return "account(\(accountId.accountId))"
        case .contract(let contractId):
            return "contract(\(contractId.wrapped.hexEncodedString()))"
        }
    }
}

// MARK: - Result Types

/// Complete result of contract inspection
public struct ContractInspectionResult {
    public let contractId: String?
    public let wasmId: String?
    public let interfaceVersion: UInt64
    public let functions: [ContractFunction]
    public let customTypes: ContractCustomTypes
    public let metadata: [String: String]
    
    /// Generates a human-readable summary of the contract
    public func summary() -> String {
        var output = "📋 Smart Contract Inspection Report\n"
        output += "═══════════════════════════════════\n\n"
        
        if let contractId = contractId {
            output += "Contract ID: \(contractId)\n"
        }
        if let wasmId = wasmId {
            output += "WASM ID: \(wasmId)\n"
        }
        output += "Interface Version: \(interfaceVersion)\n\n"
        
        // Metadata
        if !metadata.isEmpty {
            output += "📌 Metadata:\n"
            for (key, value) in metadata {
                output += "  • \(key): \(value)\n"
            }
            output += "\n"
        }
        
        // Functions
        output += "🔧 Available Functions (\(functions.count)):\n"
        for function in functions {
            output += "\n  ▸ \(function.name)("
            output += function.inputs.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
            output += ")"
            if !function.outputs.isEmpty {
                output += " → \(function.outputs.joined(separator: ", "))"
            }
            if let doc = function.doc, !doc.isEmpty {
                output += "\n    📖 \(doc)"
            }
        }
        
        // Custom Types
        if !customTypes.isEmpty {
            output += "\n\n📦 Custom Types:\n"
            
            if !customTypes.structs.isEmpty {
                output += "\n  Structs:\n"
                for struct_ in customTypes.structs {
                    output += "    • \(struct_.name)\n"
                }
            }
            
            if !customTypes.enums.isEmpty {
                output += "\n  Enums:\n"
                for enum_ in customTypes.enums {
                    output += "    • \(enum_.name)\n"
                }
            }
            
            if !customTypes.errors.isEmpty {
                output += "\n  Errors:\n"
                for error in customTypes.errors {
                    output += "    • \(error.name)\n"
                }
            }
        }
        
        return output
    }
}

/// Represents a contract function
public struct ContractFunction {
    public let name: String
    public let doc: String?
    public let inputs: [FunctionParameter]
    public let outputs: [String]
}

/// Represents a function parameter
public struct FunctionParameter {
    public let name: String
    public let type: String
    public let doc: String?
}

/// Container for all custom types in the contract
public struct ContractCustomTypes {
    public var structs: [ContractStruct] = []
    public var unions: [ContractUnion] = []
    public var enums: [ContractEnum] = []
    public var errors: [ContractError] = []
    
    var isEmpty: Bool {
        return structs.isEmpty && unions.isEmpty && enums.isEmpty && errors.isEmpty
    }
}

/// Represents a contract struct
public struct ContractStruct {
    public let name: String
    public let doc: String?
    public let fields: [StructField]
}

/// Represents a struct field
public struct StructField {
    public let name: String
    public let type: String
    public let doc: String?
}

/// Represents a contract union
public struct ContractUnion {
    public let name: String
    public let doc: String?
    public let cases: [UnionCase]
}

/// Represents a union case
public struct UnionCase {
    public let kind: SCSpecUDTUnionCaseV0Kind
    public let name: String
    public let type: String?
    public let doc: String?
}

/// Represents a contract enum
public struct ContractEnum {
    public let name: String
    public let doc: String?
    public let cases: [EnumCase]
}

/// Represents an enum case
public struct EnumCase {
    public let name: String
    public let value: UInt32
    public let doc: String?
}

/// Represents a contract error
public struct ContractError {
    public let name: String
    public let doc: String?
    public let cases: [ErrorCase]
}

/// Represents an error case
public struct ErrorCase {
    public let name: String
    public let value: UInt32
    public let doc: String?
}

/// Result of contract data query
public struct ContractDataResult {
    public let key: String
    public let value: String
    public let durability: ContractDataDurability
    public let lastModifiedLedger: Int
    
    public func summary() -> String {
        var output = "📊 Contract Data Entry\n"
        output += "Key: \(key)\n"
        output += "Value: \(value)\n"
        output += "Durability: \(durability == .persistent ? "Persistent" : "Temporary")\n"
        output += "Last Modified: Ledger \(lastModifiedLedger)\n"
        return output
    }
}

// MARK: - Errors

public enum ContractInspectionError: Error, LocalizedError {
    case parsingFailed(String)
    case rpcFailed(String)
    case invalidContractId
    case dataNotFound
    
    public var errorDescription: String? {
        switch self {
        case .parsingFailed(let message):
            return "Parsing failed: \(message)"
        case .rpcFailed(let message):
            return "RPC request failed: \(message)"
        case .invalidContractId:
            return "Invalid contract ID provided"
        case .dataNotFound:
            return "Requested data not found"
        }
    }
}

// MARK: - Extensions

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
} 
