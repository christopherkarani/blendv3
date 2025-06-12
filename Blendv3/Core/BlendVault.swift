//
//  BlendVault.swift
//  Blendv3
//
//  Refactored Blend Vault - Orchestrates all services
//
import stellarsdk


class BlendVault {
    private let oracleService: BlendOracleServiceProtocol
    private let poolService: PoolServiceProtocol
    private let backstopService: BackstopContractServiceProtocol
    private let cacheService: CacheServiceProtocol
    
    init(oracleService: BlendOracleServiceProtocol,
         poolService: PoolServiceProtocol,
         backstopService: BackstopContractServiceProtocol,
         cache: CacheServiceProtocol) {
        
        self.oracleService = oracleService
        self.poolService = poolService
        self.backstopService = backstopService
        self.cacheService = cache
    }
    
    func start() async {
        let decimaps = try! await oracleService.getOracleDecimals()
        let supportedAssets = try! await oracleService.getSupportedAssets()
        print("Supported Assets count: ", supportedAssets)
    }
}


@main
struct Start {
    static func main() async {
        // Entry point: Add startup code here as needed
        print("BlendVault application started.")
        let account = try! KeyPair(secretSeed: "SATOWQKPSRAP7D77C6EMT65OIF543WQUOV6DJBPW4SGUNTP2XSIEVUKP")
        let networkService: NetworkService = .init()
        let cacheService = CacheService()
        let poolService = PoolService(networkService: networkService, sourceKeyPair: account)
        let oracleService = BlendOracleService(cacheService: cacheService, networkService: networkService)
        var rpcEndpoint: String = BlendConstants.RPC.testnet
        
        
        let backstopContractAddress = BlendConstants.Testnet.backstop
        let config = BackstopServiceConfig
            .init(
                contractAddress: backstopContractAddress,
                rpcUrl: rpcEndpoint,
                network: .testnet
            )
        let backstopService = BackstopContractService(networkService: networkService, cacheService: cacheService, config: config)

        let vault = BlendVault(oracleService: oracleService, poolService: poolService, backstopService: backstopService, cache: cacheService)
        
        
            await  vault.start()
        
       
        
        
    }
}
