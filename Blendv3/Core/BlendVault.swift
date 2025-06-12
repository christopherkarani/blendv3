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
    private let account: KeyPair
    private let networkService: NetworkService
    private let poolID: String = BlendConstants.Testnet.xlmUsdcPool
    private var backstopContractID: String = BlendConstants.Testnet.backstop
    private var oracleAddress: String = BlendConstants.Testnet.oracle
    
    @MainActor
    init(oracleService: BlendOracleServiceProtocol,
         poolService: PoolServiceProtocol,
         backstopService: BackstopContractServiceProtocol,
         cache: CacheServiceProtocol) {
        
        self.oracleService = oracleService
        self.poolService = poolService
        self.backstopService = backstopService
        self.cacheService = cache
        self.account =  try! KeyPair(secretSeed: "SATOWQKPSRAP7D77C6EMT65OIF543WQUOV6DJBPW4SGUNTP2XSIEVUKP")
        self.networkService = NetworkService(keyPair: account)
    }
    
    func start() async {
        let decimals = try! await oracleService.getOracleDecimals()
        let supportedAssets = try! await oracleService.getSupportedAssets()
        let assetString: [String: String] = supportedAssets.reduce(into: [:]) { dict, asset in
            if case .stellar(let contractAddress) = asset {
                let value = BlendParser.getAssetSymbol(for: contractAddress)
                dict[contractAddress] = value
            }
        }
        
      
        
        let prices = try! await oracleService.getPrices(assets: supportedAssets)
        
        let poolData = try! await poolService.fetchPoolConfig(contractId: BlendConstants.Testnet.xlmUsdcPool)
        let backstop = try! await backstopService.getPoolData(pool: )
        let assetService = BlendAssetService(poolID: BlendConstants.Testnet.xlmUsdcPool, networkService: networkService)
        
        let assets = try! await assetService.getAssets()
        let assetData = try! await assetService.getAll(assets: assets)
        
        print("Asset Data: ", assetData)
    }
}


@main
struct Start {
    static func main() async {
        // Entry point: Add startup code here as needed
        print("BlendVault application started.")
        let account = try! KeyPair(secretSeed: "SATOWQKPSRAP7D77C6EMT65OIF543WQUOV6DJBPW4SGUNTP2XSIEVUKP")
        let networkService: NetworkService = .init(keyPair: account)
        let cacheService = CacheService()
        let poolService = PoolService(networkService: networkService)
        let oracleService = BlendOracleService(poolId: BlendConstants.Testnet.oracle, cacheService: cacheService, networkService: networkService, sourceKeyPair: account)
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

