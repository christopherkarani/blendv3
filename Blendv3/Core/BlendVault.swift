import Foundation
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
    private var assetService: BlendAssetServiceProtocol
    private var userService: UserPositionService
    
    @MainActor
    init(oracleService: BlendOracleServiceProtocol,
         poolService: PoolServiceProtocol,
         backstopService: BackstopContractServiceProtocol,
         cache: CacheServiceProtocol,
         assetService: BlendAssetServiceProtocol,
         userService: UserPositionService) {
        
        self.oracleService = oracleService
        self.poolService = poolService
        self.backstopService = backstopService
        self.cacheService = cache
        self.account =  try! KeyPair(secretSeed: "SATOWQKPSRAP7D77C6EMT65OIF543WQUOV6DJBPW4SGUNTP2XSIEVUKP")
        self.networkService = NetworkService(keyPair: account)
        self.assetService = assetService
        self.userService = userService
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
        let backstop = try! await backstopService.getPoolData(pool: BlendConstants.Testnet.backstop)
        let assetService = BlendAssetService(poolID: BlendConstants.Testnet.xlmUsdcPool, networkService: networkService)
        
        let assets = try! await assetService.getAssets()
        let assetData = try! await assetService.getAll(assets: assets)
        
        let positions = try! await userService.getPositions()
        let asset = BlendConstants.Testnet.xlm
        //try! await userService.submit(requestType: 2, amount: "100", asset: asset)
        
        let result = try! await networkService.loadTokenMetadata(contractId: BlendConstants.Testnet.usdc)
        let humanR = FixedMath.toFixed(value: Double(poolData.backstopRate), decimals: decimals)
        
        
        let backstopTakeRate = Decimal(poolData.backstopRate)
        
        let contractName = try! StellarContractID.toStrKey(assetData[3].assetId)
        let borrowAPY = try! assetData[3].calculateBorrowAPY()
        let borrowAPR = try! assetData[3].calculateBorrowAPR()
        let supplyAPY = try! assetData[3].calculateSupplyAPR(backstopTakeRate: backstopTakeRate)
        let supplyAPR = try! assetData[3].calculateSupplyAPR(backstopTakeRate: backstopTakeRate)
        
        print("Contract: ", contractName)
        print("Token Data: ", assetData[3])
        print("backstopTakeRate:", backstopTakeRate)
        print("borrowAPY:", borrowAPY)
        print("borrowAPR:", borrowAPR)
        print("supplyAPY:", supplyAPY)
        print("supplyAPR:", supplyAPR)
        
       
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
        let rpcEndpoint: String = BlendConstants.RPC.testnet
        let poolID = BlendConstants.Testnet.xlmUsdcPool
        let assetService = BlendAssetService(poolID: BlendConstants.Testnet.xlmUsdcPool, networkService: networkService)
        let userService: UserPositionService = UserPositionService(cacheService: cacheService, networkService: networkService, contractID: poolID, userAccountID: account.accountId)
        let backstopContractAddress = BlendConstants.Testnet.backstop
        let config = BackstopServiceConfig
            .init(
                contractAddress: backstopContractAddress,
                rpcUrl: rpcEndpoint,
                network: .testnet
            )
        let backstopService = BackstopContractService(networkService: networkService, cacheService: cacheService, config: config)

        let vault = BlendVault(oracleService: oracleService, poolService: poolService, backstopService: backstopService, cache: cacheService, assetService: assetService, userService: userService)
        
        
            await  vault.start()
        
       
        
        
    }
}

