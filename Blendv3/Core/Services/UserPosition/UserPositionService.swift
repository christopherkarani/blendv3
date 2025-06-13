//
//  UserPositionService.swift
//  Blendv3
//
//  Service for managing user positions and related calculations
//  Implements Swift 6.0 features including typed throws and strict concurrency checking
//

//import Foundation
//import stellarsdk
//
///// Service for managing user positions and related calculations
//@MainActor
//final class UserPositionService: UserPositionServiceProtocol {
//    
//    // MARK: - Properties
//
// 
//    private let cacheService: CacheServiceProtocol
//    private let networkService: NetworkServiceProtocol
//    private let logger: DebugLogger
//    
//    let contractID: String
//    
//    // MARK: - Cache Keys
//    
//    private enum CacheKeys {
//        static func userPosition(_ userId: String) -> String { "user_position_\(userId)" }
//        static func userAssetPositions(_ userId: String) -> String { "user_asset_positions_\(userId)" }
//        static func healthFactor(_ userId: String) -> String { "health_factor_\(userId)" }
//        static func claimableEmissions(_ userId: String) -> String { "claimable_emissions_\(userId)" }
//    }
//    
//    // MARK: - Initialization
//    
//    init(
//        contractID: String,
//        networkService: NetworkServiceProtocol,
//        cacheService: CacheServiceProtocol,
//
//    ) {
//        self.networkService = networkService
//        self.cacheService = cacheService
//        self.contractID = contractID
//        self.logger = DebugLogger(subsystem: "com.blendv3.userposition", category: "UserPositionService")
//    }
//    
//    // MARK: - UserPositionServiceProtocol Implementation
//    
//    func fetchUserPosition(userId: String) async throws -> UserPositionData {
//        logger.debug("Fetching user position for: \(userId)")
//        
//        // Check cache first
//        let cacheKey = CacheKeys.userPosition(userId)
//        if let cached = await cacheService.get(cacheKey, type: UserPositionData.self) {
//            logger.debug("Returning cached user position")
//            return cached
//        }
//        
//        // Fetch user asset positions
//        let positionsResult = try await fetchUserAssetPositions(userId: userId)
//        let positions = positionsResult
//        
//        
//        // Calculate health factor
//        let healthFactorResult = try await calculateHealthFactor(userId: userId)
//        let healthFactor = healthFactorResult
//        
//        // Get reserve data for APY calculations
//        let reserveData = try await fetchReserveData()
//        
//
//        // Get claimable emissions
//        let emissionsResult = try await fetchClaimableEmissions(userId: userId)
//        let emissions = emissionsResult
//        
//        let position = UserPositionData (
//            userId: userId,
//            supplied: usdcPosition.supplied,
//            borrowed: usdcPosition.borrowed,
//            collateral: usdcPosition.collateral,
//            availableToBorrow: usdcPosition.availableToBorrow,
//            healthFactor: healthFactor,
//            netAPY: netAPY,
//            claimableEmissions: emissions
//        )
//        
//        // Cache the result
//        await self.cacheService.set(
//            position,
//            key: cacheKey,
//            ttl: 60 // 1 minute cache for user positions
//        )
//        
//        logger.info("User position fetched successfully")
//        return position
//    }
//    
//    func fetchUserAssetPositions(userId: String) async throws -> [AssetPosition] {
//        logger.debug("Fetching user asset positions for: \(userId)")
//        
//        // Skip cache temporarily to ensure functionality
//        // We'll re-implement caching once core functionality works
//        
//        let positions = try await fetchUserPositionsFromContract(userId: userId)
//        
//        // Temporarily disabled caching
//        // We'll re-implement once core functionality works
//        
//        logger.info("User asset positions fetched successfully")
//        return positions
//    }
//    
//    func calculateHealthFactor(userId: String) async throws -> Decimal {
//        logger.debug("Calculating health factor for: \(userId)")
//        
//        // Check cache first
//        let cacheKey = CacheKeys.healthFactor(userId)
//        if let cached = await cacheService.get(cacheKey, type: Decimal.self) {
//            logger.debug("Returning cached health factor")
//            return cached
//        }
//        
//        let healthFactor = try await calculateHealthFactorFromContract(userId: userId)
//        
//        // Cache the result
//        await self.cacheService.set(
//            healthFactor,
//            key: cacheKey,
//            ttl: 30 // 30 second cache for health factor
//        )
//        
//        logger.info("Health factor calculated successfully")
//        return healthFactor
//    }
//    
//    func fetchClaimableEmissions(userId: String) async throws -> Decimal {
//        logger.debug("Fetching claimable emissions for: \(userId)")
//        
//        // Check cache first
//        let cacheKey = CacheKeys.claimableEmissions(userId)
//        if let cached = await cacheService.get(cacheKey, type: Decimal.self) {
//            logger.debug("Returning cached claimable emissions")
//            return cached
//        }
//        
//        let emissions = try await fetchClaimableEmissionsFromContract(userId: userId)
//        
//        // Cache the result
//        await self.cacheService.set(
//            emissions,
//            key: cacheKey,
//            ttl: 60 // 1 minute cache
//        )
//        
//        logger.info("Claimable emissions fetched successfully")
//        return emissions
//    }
//    
//    // MARK: - Calculation Methods
//    
// 
//    
//    func calculateAvailableToBorrow(
//        collateral: Decimal,
//        borrowed: Decimal,
//        collateralFactor: Decimal
//    ) -> Decimal {
//        let maxBorrowable = collateral * collateralFactor
//        return max(0, maxBorrowable - borrowed)
//    }
//    
//    // MARK: - Cache Management
//    
//    func clearUserPositionCache(userId: String) async {
//        logger.debug("Clearing position cache for user: \(userId)")
//        
//        await cacheService.remove(CacheKeys.userPosition(userId))
//        await cacheService.remove(CacheKeys.userAssetPositions(userId))
//        await cacheService.remove(CacheKeys.healthFactor(userId))
//        await cacheService.remove(CacheKeys.claimableEmissions(userId))
//        
//        logger.info("Position cache cleared for user: \(userId)")
//    }
//    
//    func clearAllPositionCache() async {
//        logger.debug("Clearing all position cache")
//        
//        // This would ideally use a pattern-based cache clear
//        // For now, we'll need to implement this based on the cache service capabilities
//        logger.warning("clearAllPositionCache not fully implemented - requires pattern-based cache clearing")
//    }
//}
//
//// MARK: - Private Contract Methods
//
//private extension UserPositionService {
//    
//    func fetchUserPositionsFromContract(userId: String) async throws -> [AssetPosition] {
//        logger.debug("Fetching user positions from contract")
//        
//        let response = try await networkService.invokeContractFunction(
//            contractId: configuration.contractAddresses.poolAddress,
//            functionName: "get_positions",
//            args: [
//                SCValXDR.address(try SCAddressXDR(accountId: userId))
//            ]
//        )
//        
////        let contractParams = ContractCallParams(contractId: <#T##String#>, functionName: <#T##String#>, functionArguments: <#T##[SCValXDR]#>)
////
////        networkService.invokeContractFunction(contractCall: <#T##ContractCallParams#>, force: <#T##Bool#>)
//        
//        // Parse response
//        guard case .map(let positionsMap) = response else {
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        var positions: [AssetPosition] = []
//        
//        if let entries = positionsMap {
//            for entry in entries {
//                let key = entry.key
//                let value = entry.val
//                guard case .address(let assetAddress) = key,
//                      case .map(let positionData) = value else { continue }
//                
//                var supplied: Decimal = 0
//                var borrowed: Decimal = 0
//                var collateral: Decimal = 0
//                
//                for entry in positionData ?? [] {
//                    guard case .symbol(let symbol) = entry.key else { continue }
//                    let posValue = entry.val
//                    
//                    switch symbol {
//                    case "supply":
//                        if case .i128(let i128) = posValue {
//                            supplied = try validation.validateI128(i128) / Decimal(10_000_000)
//                        }
//                    case "liabilities":
//                        if case .vec(let liabilities) = posValue {
//                            // Sum all liabilities
//                            for liability in liabilities ?? [] {
//                                if case .i128(let i128) = liability {
//                                    borrowed += try validation.validateI128(i128) / Decimal(10_000_000)
//                                }
//                            }
//                        }
//                    case "collateral":
//                        if case .i128(let i128) = posValue {
//                            collateral = try validation.validateI128(i128) / Decimal(10_000_000)
//                        }
//                    default:
//                        break
//                    }
//                }
//                
//                // Calculate available to borrow based on collateral
//                let availableToBorrow = calculateAvailableToBorrow(
//                    collateral: collateral,
//                    borrowed: borrowed,
//                    collateralFactor: Decimal(0.75) // 75% LTV
//                )
//                
//                positions.append(AssetPosition(
//                    assetId: assetAddress.contractId ?? "",
//                    supplied: supplied,
//                    borrowed: borrowed,
//                    collateral: collateral,
//                    availableToBorrow: availableToBorrow
//                ))
//            }
//        }
//        
//        return positions
//    }
//    
//    func calculateHealthFactorFromContract(userId: String) async throws -> Decimal {
//        logger.debug("Calculating health factor from contract")
//        
//        let response = try await networkService.invokeContractFunction(
//            contractId: configuration.contractAddresses.poolAddress,
//            functionName: "user_health",
//            args: [
//                SCValXDR.address(try SCAddressXDR(accountId: userId))
//            ]
//        )
//        
//        // Parse response - expecting a u32 percentage (10000 = 100%)
//        guard case .u32(let healthValue) = response else {
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Convert to decimal (1.0 = 100% health)
//        return Decimal(healthValue) / 10000
//    }
//    
//    func fetchClaimableEmissionsFromContract(userId: String) async throws -> Decimal {
//        logger.debug("Fetching claimable emissions from contract")
//        
//        let response = try await networkService.invokeContractFunction(
//            contractId: configuration.contractAddresses.emissionsAddress,
//            functionName: "get_claimable",
//            args: [
//                SCValXDR.address(try SCAddressXDR(accountId: userId)),
//                SCValXDR.u32(0) // Pool ID
//            ]
//        )
//        
//        // Parse response
//        guard case .i128(let i128) = response else {
//            // No emissions available
//            return 0
//        }
//        
//        return try validation.validateI128(i128) / Decimal(10_000_000)
//    }
//    
//    
//}
