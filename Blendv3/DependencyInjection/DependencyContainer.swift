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
@MainActor public final class DependencyContainer {
    
    // MARK: - Singleton
    
    public static var shared = DependencyContainer()
    
    // MARK: - Services
    

    
    /// Rate calculator for APR/APY calculations
    public lazy var rateCalculator: BlendRateCalculatorProtocol = BlendRateCalculator()
    
    /// Oracle service for price retrieval
    public lazy var oracleService: BlendOracleServiceProtocol = BlendOracleService(
        cacheService: cacheService,
        networkService: networkService
    )
    
    /// Cache service for data persistence
    public lazy var cacheService: CacheServiceProtocol = CacheService()
    
    /// Configuration service for environment settings
    public lazy var configurationService: ConfigurationServiceProtocol = ConfigurationService(
        networkType: .testnet
    )
    
    /// Network service for RPC calls
    @MainActor public lazy var networkService: NetworkServiceProtocol = NetworkService(
        configuration: configurationService
    )
    
    // MARK: - Test Support
    
    /// Reset container for testing
    public func reset() {
        _rateCalculator = nil
        _oracleService = nil
        _cacheService = nil
        _networkService = nil
        _configurationService = nil
    }
    
    // MARK: - Private Storage
    
    private var _rateCalculator: BlendRateCalculatorProtocol?
    private var _oracleService: BlendOracleServiceProtocol?
    private var _cacheService: CacheServiceProtocol?
    private var _networkService: NetworkServiceProtocol?
    private var _configurationService: ConfigurationServiceProtocol?
    
    // MARK: - Initialization
    
    private init() {}
}

