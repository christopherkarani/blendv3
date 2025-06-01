//
//  ErrorBoundaryService.swift
//  Blendv3
//
//  Error handling and recovery service
//

import Foundation
import stellarsdk

/// Centralized error handling service with retry logic and error sanitization
final class ErrorBoundaryService: ErrorBoundaryServiceProtocol {
    
    // MARK: - Properties
    
    private let logger: DebugLogger
    private let diagnostics: DiagnosticsServiceProtocol?
    
    // MARK: - Initialization
    
    init(diagnostics: DiagnosticsServiceProtocol? = nil) {
        self.diagnostics = diagnostics
        self.logger = DebugLogger(subsystem: "com.blendv3.error", category: "ErrorBoundary")
    }
    
    // MARK: - ErrorBoundaryServiceProtocol
    
    func handle<T>(_ operation: () async throws -> T) async -> Result<T, BlendError> {
        do {
            let result = try await operation()
            return .success(result)
        } catch {
            let blendError = mapToBlendError(error)
            logError(blendError, context: ErrorContext(
                operation: "Unknown",
                timestamp: Date(),
                metadata: ["originalError": String(describing: error)]
            ))
            return .failure(blendError)
        }
    }
    
    func handleWithRetry<T>(_ operation: () async throws -> T, maxRetries: Int) async -> Result<T, BlendError> {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let result = try await operation()
                
                // Log successful retry if it wasn't the first attempt
                if attempt > 0 {
                    logger.info("Operation succeeded after \(attempt) retries")
                }
                
                return .success(result)
            } catch {
                lastError = error
                let blendError = mapToBlendError(error)
                
                // Check if error is recoverable
                guard isRecoverableError(blendError) else {
                    logError(blendError, context: ErrorContext(
                        operation: "Retry",
                        timestamp: Date(),
                        metadata: [
                            "attempt": attempt + 1,
                            "maxRetries": maxRetries,
                            "recoverable": false
                        ]
                    ))
                    return .failure(blendError)
                }
                
                // Calculate backoff delay
                let delay = calculateBackoffDelay(attempt: attempt)
                
                logger.debug("Attempt \(attempt + 1) failed, retrying in \(delay)s")
                
                // Wait before retry
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // All retries exhausted
        let finalError = mapToBlendError(lastError ?? NSError(domain: "Unknown", code: -1))
        logError(finalError, context: ErrorContext(
            operation: "Retry",
            timestamp: Date(),
            metadata: [
                "exhaustedRetries": true,
                "maxRetries": maxRetries
            ]
        ))
        
        return .failure(finalError)
    }
    
    func logError(_ error: Error, context: ErrorContext) {
        // Log to our logger
        logger.error("Error in \(context.operation): \(error.localizedDescription)")
        
        // Log to diagnostics if available
        if let diagnostics = diagnostics {
            diagnostics.logNetworkEvent(NetworkEvent(
                timestamp: context.timestamp,
                type: .connectionFailure,
                details: error.localizedDescription,
                duration: nil
            ))
        }
        
        // Log metadata for debugging (only in debug builds)
        #if DEBUG
        for (key, value) in context.metadata {
            logger.debug("  \(key): \(value)")
        }
        #endif
    }
    
    // MARK: - Private Methods
    
    /// Map any error to a sanitized BlendError that doesn't expose internal details
    private func mapToBlendError(_ error: Error) -> BlendError {
        // Check if already a BlendError
        if let blendError = error as? BlendError {
            return blendError
        }
        
        // Map BlendVaultError to BlendError
        if let vaultError = error as? BlendVaultError {
            switch vaultError {
            case .notInitialized:
                return .initialization("Service not ready")
            case .invalidAmount:
                return .validation(.invalidInput)
            case .insufficientBalance:
                return .insufficientFunds
            case .transactionFailed:
                return .transaction(.failed)
            case .networkError:
                return .network(.connectionFailed)
            case .initializationFailed:
                return .initialization("Setup failed")
            case .invalidResponse:
                return .validation(.invalidResponse)
            case .unknown:
                return .unknown
            }
        }
        
        // Map network errors
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .network(.timeout)
            case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
                return .network(.connectionFailed)
            case NSURLErrorBadServerResponse:
                return .network(.serverError)
            default:
                return .network(.connectionFailed)
            }
        }
        
        // Map Soroban RPC errors
        if let rpcError = error as? stellarsdk.SorobanRpcRequestError {
            switch rpcError {
            case .requestFailed:
                return .network(.connectionFailed)
            case .errorResponse:
                return .network(.serverError)
            case .parsingResponseFailed:
                return .validation(.invalidResponse)
            }
        }
        
        // Default to unknown for any unmapped errors
        logger.debug("Unmapped error type: \(type(of: error))")
        return .unknown
    }
    
    /// Check if an error is recoverable (can be retried)
    private func isRecoverableError(_ error: BlendError) -> Bool {
        switch error {
        case .network:
            return true // All network errors are recoverable
        case .serviceUnavailable:
            return true
        case .transaction(.failed):
            return true // Some transaction failures might be temporary
        case .validation, .initialization, .unauthorized, .insufficientFunds, .unknown:
            return false // These are not recoverable through retry
        case .transaction(.rejected), .transaction(.insufficientFee):
            return false // These require user action
        case .assetRetrivalFailed:
            return false 
        }
    }
    
    /// Calculate exponential backoff delay with jitter
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 30.0
        let exponentialBase: Double = 2.0
        
        // Calculate exponential delay
        let exponentialDelay = min(baseDelay * pow(exponentialBase, Double(attempt)), maxDelay)
        
        // Add jitter (0-30% of delay)
        let jitter = Double.random(in: 0...0.3) * exponentialDelay
        
        return exponentialDelay + jitter
    }
} 
