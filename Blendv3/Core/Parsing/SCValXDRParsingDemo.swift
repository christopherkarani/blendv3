//
//  SCValXDRParsingDemo.swift
//  Blendv3
//
//  Demonstration of enhanced SCValXDR parsing capabilities
//

import Foundation
import stellarsdk

/// Demonstration class for enhanced SCValXDR parsing
public final class SCValXDRParsingDemo {
    
    private let logger = DebugLogger(subsystem: "com.blendv3.demo", category: "SCValXDRParsing")
    
    /// Demonstrate parsing of u32 value (like the failing u32: 7 case)
    public func demonstrateU32Parsing() {
        logger.info("🧪 Demonstrating U32 parsing...")
        
        // Create a u32 SCValXDR with value 7
        let u32Value = SCValXDR.u32(7)
        
        logger.info("✅ Created SCValXDR.u32(7): \(u32Value.debugDescription)")
        
        // Test safe extraction
        if let extractedValue = u32Value.safeU32 {
            logger.info("✅ Safely extracted u32 value: \(extractedValue)")
        } else {
            logger.error("❌ Failed to extract u32 value")
        }
        
        // Test validation and extraction
        do {
            let validatedValue = try u32Value.validateAndExtractU32()
            logger.info("✅ Validated and extracted u32 value: \(validatedValue)")
        } catch {
            logger.error("❌ Validation failed: \(error)")
        }
        
        // Test with BlendParser
        let parser = BlendParser()
        do {
            let parsedValue = try parser.parseUInt32(u32Value)
            logger.info("✅ BlendParser successfully parsed u32: \(parsedValue)")
        } catch {
            logger.error("❌ BlendParser failed: \(error)")
        }
    }
    
    /// Demonstrate transaction status code handling
    public func demonstrateTransactionStatusParsing() {
        logger.info("🧪 Demonstrating Transaction Status parsing...")
        
        // Simulate different transaction status scenarios
        let successStatus = SimulationTransactionStatus(
            statusCode: "SUCCESS",
            isSuccess: true,
            errorDetails: nil,
            costInfo: TransactionCost(cpuInstructions: 1000, memoryBytes: 512, resourceFee: 100)
        )
        
        let failureStatus = SimulationTransactionStatus(
            statusCode: "FAILED",
            isSuccess: false,
            errorDetails: "Contract execution failed: insufficient balance",
            costInfo: nil
        )
        
        logTransactionStatus(successStatus, operation: "getUserBalance")
        logTransactionStatus(failureStatus, operation: "withdrawFunds")
    }
    
    /// Demonstrate XDR string parsing with error handling
    public func demonstrateXDRStringParsing() {
        logger.info("🧪 Demonstrating XDR string parsing...")
        
        // Test with a valid u32 XDR (base64 encoded)
        let validU32XDR = "AAAAAwAAAAc=" // This represents u32 value 7
        
        do {
            let parsedValue = try SCValXDR(xdr: validU32XDR)
            logger.info("✅ Successfully parsed XDR: \(parsedValue.debugDescription)")
            
            // Log detailed debug info
            parsedValue.logDebugInfo(logger: logger)
            
        } catch let error as SCValXDRError {
            logger.error("❌ Enhanced XDR parsing failed: \(error.localizedDescription)")
        } catch {
            logger.error("❌ Generic XDR parsing failed: \(error)")
        }
        
        // Test with invalid XDR
        let invalidXDR = "invalid_xdr_string"
        do {
            let _ = try SCValXDR(xdr: invalidXDR)
            logger.info("❌ Should have failed to parse invalid XDR")
        } catch let error as SCValXDRError {
            logger.info("✅ Correctly caught enhanced XDR error: \(error.localizedDescription)")
        } catch {
            logger.info("✅ Correctly caught generic error: \(error)")
        }
    }
    
    /// Demonstrate reduced logging approach
    public func demonstrateReducedLogging() {
        logger.info("🧪 Demonstrating reduced logging approach...")
        
        // Only log critical information
        logger.info("💡 Critical: Starting important operation")
        
        // Example of what we DON'T log anymore (debug level operations)
        // logger.debug("Processing item 1 of 100") // REMOVED
        // logger.debug("Processing item 2 of 100") // REMOVED
        
        // Only log errors and warnings
        logger.warning("⚠️ Warning: Non-critical issue detected")
        logger.error("❌ Error: Critical failure occurred")
        
        logger.info("💡 Critical: Operation completed successfully")
    }
    
    // MARK: - Private Helper Methods
    
    private func logTransactionStatus(_ status: SimulationTransactionStatus, operation: String) {
        logger.info("📊 Transaction Status for \(operation):")
        logger.info("  Status Code: \(status.statusCode)")
        logger.info("  Success: \(status.isSuccess)")
        
        if let costInfo = status.costInfo {
            logger.info("  💰 Cost - CPU: \(costInfo.cpuInstructions), Memory: \(costInfo.memoryBytes), Fee: \(costInfo.resourceFee)")
        }
        
        if let errorDetails = status.errorDetails {
            logger.error("  ❌ Error: \(errorDetails)")
        }
    }
}

// MARK: - Usage Example

extension SCValXDRParsingDemo {
    
    /// Run all demonstrations
    public static func runAllDemonstrations() {
        let demo = SCValXDRParsingDemo()
        
        demo.demonstrateU32Parsing()
        demo.demonstrateTransactionStatusParsing()
        demo.demonstrateXDRStringParsing()
        demo.demonstrateReducedLogging()
    }
} 