import Foundation

/// Property wrapper for dependency injection
@propertyWrapper
public struct Injected<T> {
    private let keyPath: WritableKeyPath<DependencyContainer, T>
    
    public var wrappedValue: T {
        get { DependencyContainer.shared[keyPath: keyPath] }
        set { DependencyContainer.shared[keyPath: keyPath] = newValue }
    }
    
    public init(_ keyPath: WritableKeyPath<DependencyContainer, T>) {
        self.keyPath = keyPath
    }
}

/// Central dependency container for the application
public final class DependencyContainer {
    
    // MARK: - Singleton
    
    public static var shared = DependencyContainer()
    
    // MARK: - Services
    
    /// USDC Vault service for blockchain interactions
    public lazy var vaultService: BlendUSDCVault = {
        let signer = BlendDefaultSigner()
        return BlendUSDCVault(signer: signer, network: .testnet)
    }()
    
    /// Rate calculator for APR/APY calculations
    public lazy var rateCalculator: BlendRateCalculatorProtocol = BlendRateCalculator()
    
    /// Oracle service for price retrieval
    public lazy var oracleService: BlendOracleServiceProtocol = BlendOracleService(
        networkService: networkService,
        cacheService: cacheService
    )
    
    /// Network service for RPC calls
    public lazy var networkService: NetworkServiceProtocol = NetworkService()
    
    /// Cache service for data persistence
    public lazy var cacheService: CacheServiceProtocol = CacheService()
    
    // MARK: - Test Support
    
    /// Reset container for testing
    public func reset() {
        _vaultService = nil
        _rateCalculator = nil
        _oracleService = nil
        _networkService = nil
        _cacheService = nil
    }
    
    // MARK: - Private Storage
    
    private var _vaultService: BlendUSDCVault?
    private var _rateCalculator: BlendRateCalculatorProtocol?
    private var _oracleService: BlendOracleServiceProtocol?
    private var _networkService: NetworkServiceProtocol?
    private var _cacheService: CacheServiceProtocol?
    
    // MARK: - Initialization
    
    private init() {}
}

// MARK: - Protocol for testability

public protocol NetworkServiceProtocol {
    func simulateOperation(_ operation: Data) async throws -> Data
    func getLedgerEntries(_ keys: [String]) async throws -> [Data]
}

public protocol CacheServiceProtocol {
    func get<T: Codable>(_ key: String, type: T.Type) -> T?
    func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval)
    func remove(_ key: String)
    func clear()
} 
