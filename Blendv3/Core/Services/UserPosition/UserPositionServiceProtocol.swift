//
//  UserPositionServiceProtocol.swift
//  Blendv3
//
//  Protocol for user position management
//

import Foundation

/// Protocol for managing user positions
@MainActor
protocol UserPositionServiceProtocol: AnyObject, Sendable {
    
    // MARK: - Core Position Methods
    
    /// Fetch user position data for a specific user
    /// - Parameter userId: The user's account ID
    /// - Returns: Result containing UserPositionData or BlendError
    func fetchUserPosition(userId: String) async throws -> UserPositionData
    
    /// Fetch raw asset positions for a user
    /// - Parameter userId: The user's account ID
    /// - Returns: Result containing array of AssetPosition or BlendError
    func fetchUserAssetPositions(userId: String) async throws -> [AssetPosition]
    
    /// Calculate user's health factor
    /// - Parameter userId: The user's account ID
    /// - Returns: Result containing health factor as Decimal or BlendError
    func calculateHealthFactor(userId: String) async throws -> Decimal
    
    /// Fetch claimable emissions for a user
    /// - Parameter userId: The user's account ID
    /// - Returns: Result containing claimable emissions as Decimal or BlendError
    func fetchClaimableEmissions(userId: String) async throws -> Decimal
    
    // MARK: - Calculation Methods
    
    /// Calculate net APY for a user's position
    /// - Parameters:
    ///   - supplied: Amount supplied
    ///   - borrowed: Amount borrowed
    ///   - supplyAPY: Current supply APY
    ///   - borrowAPY: Current borrow APY
    /// - Returns: Net APY as Decimal
    func calculateNetAPY(
        supplied: Decimal,
        borrowed: Decimal,
        supplyAPY: Decimal,
        borrowAPY: Decimal
    ) -> Decimal
    
    /// Calculate available borrowing capacity
    /// - Parameters:
    ///   - collateral: Total collateral amount
    ///   - borrowed: Currently borrowed amount
    ///   - collateralFactor: Loan-to-value ratio
    /// - Returns: Available borrowing capacity as Decimal
    func calculateAvailableToBorrow(
        collateral: Decimal,
        borrowed: Decimal,
        collateralFactor: Decimal
    ) -> Decimal
    
    // MARK: - Cache Management
    
    /// Clear cached position data for a specific user
    /// - Parameter userId: The user's account ID
    func clearUserPositionCache(userId: String) async
    
    /// Clear all cached position data
    func clearAllPositionCache() async
}
