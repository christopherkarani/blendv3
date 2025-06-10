//
//  UserPositionServiceFactory.swift
//  Blendv3
//
//  Factory for creating UserPositionService instances
//

//import Foundation
//
///// Factory for creating UserPositionService instances with proper dependency injection
//@MainActor
//struct UserPositionServiceFactory {
//    
//    /// Create a UserPositionService instance with all required dependencies
//    /// - Parameters:
//    ///   - networkService: Network service for blockchain interactions
//    ///   - cacheService: Cache service for data caching
//    ///   - validation: Validation service for input/output validation
//    ///   - configuration: Configuration service for app settings
//    /// - Returns: Configured UserPositionService instance
//    static func create(
//        networkService: NetworkServiceProtocol,
//        cacheService: CacheServiceProtocol,
//        validation: ValidationServiceProtocol,
//        configuration: ConfigurationServiceProtocol
//    ) -> UserPositionServiceProtocol {
//        return UserPositionService(
//            networkService: networkService,
//            cacheService: cacheService,
//            validation: validation,
//            configuration: configuration
//        )
//    }
//    
//    /// Create a UserPositionService instance using existing DataService dependencies
//    /// - Parameter dataService: Existing DataService to extract dependencies from
//    /// - Returns: Configured UserPositionService instance
//    static func createFromDataService(_ dataService: DataService) -> UserPositionServiceProtocol {
//        // Note: This would require DataService to expose its dependencies
//        // For now, this is a placeholder for future implementation
//        fatalError("createFromDataService not yet implemented - requires DataService dependency exposure")
//    }
//}
