/// Contract call parameters for real Soroban operations
public struct ContractCallParams {
    let contractId: String
    let functionName: String
    let functionArguments: [SCValXDR]
    
    public init(contractId: String, functionName: String, functionArguments: [SCValXDR]) {
        self.contractId = contractId
        self.functionName = functionName
        self.functionArguments = functionArguments
    }
}