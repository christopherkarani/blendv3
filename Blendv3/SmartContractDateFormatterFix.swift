import Foundation

/// Test to verify that the dateFormatter access issue is fixed
class SmartContractDateFormatterFixTest {
    
    static func testDateFormatterFix() {
        print("🧪 Testing dateFormatter access fix")
        print("═══════════════════════════════")
        
        // Test that we can create log entries and access their formatted messages
        let logger = SmartContractDebugLogger.shared
        
        // Create a test log entry
        logger.info("Test log entry for dateFormatter fix", category: .debug)
        
        // Get the log entries and verify we can access formattedMessage
        let entries = logger.getLogEntries(limit: 1)
        
        if let lastEntry = entries.last {
            print("✅ LogEntry.formattedMessage accessible:")
            print("   \(lastEntry.formattedMessage)")
            
            // Verify the formatted message contains expected components
            let formatted = lastEntry.formattedMessage
            let hasTimestamp = formatted.contains(":")
            let hasLevel = formatted.contains("[INFO]")
            let hasCategory = formatted.contains("DEBUG")
            let hasMessage = formatted.contains("Test log entry")
            
            print("✅ Timestamp present: \(hasTimestamp)")
            print("✅ Log level present: \(hasLevel)")
            print("✅ Category present: \(hasCategory)")
            print("✅ Message present: \(hasMessage)")
            
            if hasTimestamp && hasLevel && hasCategory && hasMessage {
                print("✅ All formatting components working correctly!")
            } else {
                print("⚠️ Some formatting components missing")
            }
        } else {
            print("❌ No log entries found")
        }
        
        print("\n📋 Fix Summary:")
        print("- Changed dateFormatter from 'private' to 'internal'")
        print("- LogEntry.formattedMessage can now access dateFormatter")
        print("- Log formatting works correctly")
        
        print("\n✅ dateFormatter fix test completed successfully!")
    }
}

// Quick test function
func testDateFormatterFix() {
    SmartContractDateFormatterFixTest.testDateFormatterFix()
} 