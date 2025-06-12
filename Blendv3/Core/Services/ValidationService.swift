//
//  ValidationService.swift
//  Blendv3
//
//  Input/output validation and sanitization service
//

//import Foundation
//import stellarsdk
//
///// Service for validating and sanitizing all inputs and outputs
//final class ValidationService: ValidationServiceProtocol {
//    
//    // MARK: - Properties
//    
//    private let logger: DebugLogger
//    
//    // MARK: - Initialization
//    
//    init() {
//        self.logger = DebugLogger(subsystem: "com.blendv3.validation", category: "Validation")
//    }
//    
//    // MARK: - ValidationServiceProtocol
//    
//    func validateContractResponse<T>(_ response: T, schema: ValidationSchema) throws {
//        logger.debug("Validating contract response with schema: \(schema)")
//        
//        switch schema {
//        case .priceData:
//            try validatePriceData(response)
//        case .reserveData:
//            try validateReserveData(response)
//        case .poolConfig:
//            try validatePoolConfig(response)
//        case .transactionResult:
//            try validateTransactionResult(response)
//        case .i128Value:
//            try validateI128Value(response)
//        }
//    }
//    
//    func validateUserInput<T>(_ input: T, rules: ValidationRules) throws {
//        logger.debug("Validating user input")
//        
//        // Check if input is required
//        if rules.required && isNil(input) {
//            throw BlendError.validation(.invalidInput)
//        }
//        
//        // Validate numeric inputs
//        if let decimalInput = input as? Decimal {
//            if let minValue = rules.minValue, decimalInput < minValue {
//                logger.warning("Input \(decimalInput) below minimum \(minValue)")
//                throw BlendError.validation(.outOfBounds)
//            }
//            
//            if let maxValue = rules.maxValue, decimalInput > maxValue {
//                logger.warning("Input \(decimalInput) above maximum \(maxValue)")
//                throw BlendError.validation(.outOfBounds)
//            }
//        }
//        
//        // Run custom validators
//        for validator in rules.customValidators {
//            try validator(input)
//        }
//    }
//    
//    func sanitizeOutput<T>(_ output: T) -> T {
//        // For now, just return the output as-is
//        // In the future, this could strip sensitive data, format numbers, etc.
//        return output
//    }
//    
//    func validateI128(_ value: Int128PartsXDR) throws -> Decimal {
//        logger.debug("Validating I128 value: hi=\(value.hi), lo=\(value.lo)")
//        
//        // Check for integer overflow in hi part
//        guard value.hi >= Int64.min && value.hi <= Int64.max else {
//            logger.error("I128 hi part out of bounds: \(value.hi)")
//            throw BlendError.validation(.integerOverflow)
//        }
//        
//        // Check that lo is non-negative (it's unsigned)
//        guard value.lo >= 0 else {
//            logger.error("I128 lo part negative: \(value.lo)")
//            throw BlendError.validation(.invalidInput)
//        }
//        
//        // Safe conversion with overflow protection
//        let hiDecimal = Decimal(value.hi)
//        let loDecimal = Decimal(value.lo)
//        
//        // Check if hi is negative (two's complement)
//        let result: Decimal
//        if value.hi < 0 {
//            // Handle negative numbers properly
//            let maxUInt64 = Decimal(UInt64.max) + 1
//            result = hiDecimal * maxUInt64 + loDecimal
//        } else {
//            // Positive number
//            result = hiDecimal * Decimal(UInt64.max) + loDecimal
//        }
//        
//        // Sanity check result
//        guard result.isFinite && !result.isNaN else {
//            logger.error("I128 conversion produced invalid decimal")
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Check reasonable bounds for financial values
//        let maxReasonableValue = Decimal(1_000_000_000_000) // 1 trillion
//        guard abs(result) <= maxReasonableValue else {
//            logger.warning("I128 value exceeds reasonable bounds: \(result)")
//            throw BlendError.validation(.outOfBounds)
//        }
//        
//        return result
//    }
//    
//    // MARK: - Private Validation Methods
//    
//    private func validatePriceData<T>(_ response: T) throws {
//        guard let priceData = response as? PriceData else {
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Validate price is positive
//        guard priceData.price > 0 else {
//            logger.error("Invalid price: \(priceData.price)")
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Validate timestamp is reasonable (not in future, not too old)
//        let now = Date()
//        let maxAge: TimeInterval = 3600 // 1 hour
//        
//        guard priceData.timestamp <= now else {
//            logger.error("Price timestamp in future")
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        guard now.timeIntervalSince(priceData.timestamp) <= maxAge else {
//            logger.warning("Price data too old")
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Validate decimals
//        guard priceData.decimals >= 0 && priceData.decimals <= 18 else {
//            logger.error("Invalid decimals: \(priceData.decimals)")
//            throw BlendError.validation(.invalidResponse)
//        }
//    }
//    
//    private func validateReserveData<T>(_ response: T) throws {
//        guard let reserveData = response as? ReserveDataResult else {
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Validate all amounts are non-negative
//        guard reserveData.totalSupplied >= 0 else {
//            logger.error("Negative total supplied: \(reserveData.totalSupplied)")
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        guard reserveData.totalBorrowed >= 0 else {
//            logger.error("Negative total borrowed: \(reserveData.totalBorrowed)")
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Validate borrowed <= supplied (can't borrow more than exists)
//        guard reserveData.totalBorrowed <= reserveData.totalSupplied else {
//            logger.error("Borrowed exceeds supplied: \(reserveData.totalBorrowed) > \(reserveData.totalSupplied)")
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Validate rates are reasonable (0-100% APY)
//        let maxRate = Decimal(100)
//        guard reserveData.supplyAPY >= 0 && reserveData.supplyAPY <= maxRate else {
//            logger.warning("Supply APY out of range: \(reserveData.supplyAPY)")
//            throw BlendError.validation(.outOfBounds)
//        }
//        
//        guard reserveData.borrowAPY >= 0 && reserveData.borrowAPY <= maxRate else {
//            logger.warning("Borrow APY out of range: \(reserveData.borrowAPY)")
//            throw BlendError.validation(.outOfBounds)
//        }
//        
//        // Validate utilization rate
//        guard reserveData.utilizationRate >= 0 && reserveData.utilizationRate <= 1 else {
//            logger.error("Invalid utilization rate: \(reserveData.utilizationRate)")
//            throw BlendError.validation(.invalidResponse)
//        }
//    }
//    
//    private func validatePoolConfig<T>(_ response: T) throws {
//        guard let config = response as? PoolConfig else {
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Validate backstop rate (0-100%)
//        guard config.backstopRate >= 0 && config.backstopRate <= 10000 else {
//            logger.error("Invalid backstop rate: \(config.backstopRate)")
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Validate max positions
//        guard config.maxPositions > 0 && config.maxPositions <= 100 else {
//            logger.error("Invalid max positions: \(config.maxPositions)")
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        // Validate status
//        guard config.status <= 3 else { // Assuming 0-3 are valid statuses
//            logger.error("Invalid pool status: \(config.status)")
//            throw BlendError.validation(.invalidResponse)
//        }
//    }
//    
//    private func validateTransactionResult<T>(_ response: T) throws {
//        // Validate transaction hash format if it's a string
//        if let txHash = response as? String {
//            // Stellar transaction hashes are 64 characters (32 bytes hex encoded)
//            guard txHash.count == 64 else {
//                logger.error("Invalid transaction hash length: \(txHash.count)")
//                throw BlendError.validation(.invalidResponse)
//            }
//            
//            // Validate it's valid hex
//            guard txHash.allSatisfy({ $0.isHexDigit }) else {
//                logger.error("Invalid transaction hash format")
//                throw BlendError.validation(.invalidResponse)
//            }
//        }
//    }
//    
//    private func validateI128Value<T>(_ response: T) throws {
//        guard let i128 = response as? Int128PartsXDR else {
//            throw BlendError.validation(.invalidResponse)
//        }
//        
//        _ = try validateI128(i128)
//    }
//    
//    // MARK: - Helper Methods
//    
//    private func isNil<T>(_ value: T) -> Bool {
//        // Check if value is nil (for optionals)
//        if case Optional<Any>.none = value as Any {
//            return true
//        }
//        return false
//    }
//} 
