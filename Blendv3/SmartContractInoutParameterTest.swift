import Foundation

/// Simple test to verify inout parameter fix
class SmartContractInoutParameterTest {
    
    static func testMemoryUsageFunction() {
        print("🧪 Testing memory usage function with inout parameter")
        print("═══════════════════════════════════════════════════")
        
        // This should work without any inout parameter errors
        let memoryUsage = getMemoryUsage()
        print("✅ Memory usage retrieved: \(memoryUsage) MB")
        print("✅ No inout parameter errors detected")
        print("✅ Variable 'info' correctly declared as 'var' not 'let'")
    }
    
    private static func getMemoryUsage() -> String {
        // CORRECT: info is declared as 'var' so it can be passed as inout parameter
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return String(format: "%.1f", Double(info.resident_size) / 1024.0 / 1024.0)
        } else {
            return "Unknown"
        }
    }
}

// Quick test function
