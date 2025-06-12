//
//  DependencyContainer.swift
//  Blendv3
//
//  Dependency injection container for proper service initialization
//

import Foundation
import Combine

// MARK: - Dependency Container
final class DependencyContainer {
    
    // MARK: - Shared Instances
    private(set) lazy var keyProvider: KeyProviderProtocol = {
        SecureKeyProvider(keychain: keychainService)
    }()
    
    private(set) lazy var networkService: NetworkServiceProtocol = {
        NetworkService(
            session: URLSession.shared,
            keyProvider: keyProvider,
            baseURL: Configuration.baseURL
        )
    }()
    
    private(set) lazy var parser: BlendParserProtocol = {
        BlendParser()
    }()
    
    private(set) lazy var oracleService: OracleServiceProtocol = {
        OracleService(
            networkService: networkService,
            parser: parser
        )
    }()
    
    private let keychainService: KeychainServiceProtocol
    
    // MARK: - Initialization
    init(keychainService: KeychainServiceProtocol) {
        self.keychainService = keychainService
    }
    
    // MARK: - Factory Methods
    func makeOracleViewModel() -> OracleViewModel {
        OracleViewModel(
            oracleService: oracleService,
            parser: parser
        )
    }
}

// MARK: - Configuration
enum Configuration {
    static let baseURL = "https://api.blendv3.com"
    
    enum Keychain {
        static let apiKeyIdentifier = "com.blendv3.apiKey"
        static let privateKeyIdentifier = "com.blendv3.privateKey"
        static let contractAddressIdentifier = "com.blendv3.contractAddress"
    }
}

// MARK: - Example View Model
final class OracleViewModel: ObservableObject {
    @Published var currentPrice: Double = 0.0
    @Published var isLoading = false
    @Published var error: Error?
    
    private let oracleService: OracleServiceProtocol
    private let parser: BlendParserProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        oracleService: OracleServiceProtocol,
        parser: BlendParserProtocol
    ) {
        self.oracleService = oracleService
        self.parser = parser
    }
    
    func fetchPrice(for symbol: String) {
        isLoading = true
        error = nil
        
        oracleService.fetchOraclePrice(symbol: symbol)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] price in
                    self?.currentPrice = price
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Mock Keychain Implementation (for testing)
final class MockKeychainService: KeychainServiceProtocol {
    private var storage: [String: String] = [:]
    
    func retrieve(key: String) -> String? {
        return storage[key]
    }
    
    func store(key: String, value: String) -> Bool {
        storage[key] = value
        return true
    }
    
    func delete(key: String) -> Bool {
        storage.removeValue(forKey: key)
        return true
    }
}