import Foundation

/// Quick Guide for Using the Smart Contract Debug Interface
class SmartContractDebugGuide {
    
    static func printUsageGuide() {
        print("""
        🔍 SMART CONTRACT DEBUG INTERFACE - USAGE GUIDE
        ═══════════════════════════════════════════════
        
        ## 📱 How to Access the Debug Interface
        
        1. **Launch your app** - The ContentView now has 3 tabs
        2. **Tap "Debug" tab** - Second tab with magnifying glass icon
        3. **Enter a contract ID** - Use the text field at the top
        4. **Tap the search button** - Blue magnifying glass button
        
        ## 🎯 Example Contract IDs to Try
        
        ### Blend Protocol Contracts (Testnet):
        ```
        CAMKTT6LIXNOKZJVFI64EBEQE25UYAQZBTHDIQ4LEDJLTCM6YVME6IIY  (Your Blend Pool)
        CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSRCJU  (USDC Asset)
        ```
        
        ### Popular Testnet Contracts:
        ```
        CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA  (Example Contract)
        ```
        
        ## 🔍 Debug Interface Tabs
        
        ### Tab 1: Explorer 🔍
        - **Contract Overview**: Basic contract information
        - **Functions**: All available contract functions with parameters
        - **Custom Types**: Structs, enums, and custom data types
        - **WASM Analysis**: Binary size, validation, version info
        - **Contract Data**: Storage entries and key-value pairs
        
        ### Tab 2: Logs 📋
        - **Real-time Logs**: Live updates of all operations
        - **Log Filtering**: Filter by level (Debug, Info, Warning, Error)
        - **Export Logs**: Save logs for external analysis
        - **Clear Logs**: Reset the log history
        
        ### Tab 3: Performance ⚡
        - **Operation Timings**: How long each operation takes
        - **Network Activity**: RPC requests and responses
        - **Memory Usage**: Current memory consumption
        
        ### Tab 4: Settings ⚙️
        - **Log Configuration**: Adjust log levels and categories
        - **Debug Options**: Enable/disable features
        - **Data Management**: Clear logs and reset settings
        
        ## 🚀 Quick Start Steps
        
        1. **Open the Debug tab** in your app
        2. **Enter this contract ID**: `CAMKTT6LIXNOKZJVFI64EBEQE25UYAQZBTHDIQ4LEDJLTCM6YVME6IIY`
        3. **Tap the search button** (magnifying glass)
        4. **Wait for analysis** - Should take 1-3 seconds
        5. **Explore the results** in the different sections
        
        ## 📊 What You'll See
        
        ### Contract Functions
        - Function names and parameters
        - Return types
        - Documentation (if available)
        
        ### WASM Binary Info
        - File size and validation status
        - Version information
        - Magic number verification
        
        ### Performance Metrics
        - Network request timing
        - Data processing speed
        - Memory usage tracking
        
        ## 🔧 Troubleshooting
        
        ### If No Data Appears:
        1. Check the **Logs tab** for error messages
        2. Verify the contract ID is correct
        3. Ensure you have internet connection
        4. Try a different contract ID
        
        ### If App Crashes:
        1. Check the Xcode console for error messages
        2. Try clearing logs in Settings tab
        3. Restart the app
        
        ## 💡 Pro Tips
        
        1. **Use the Logs tab** to see detailed operation tracking
        2. **Export logs** to analyze performance patterns
        3. **Try different contracts** to see various structures
        4. **Monitor performance** to optimize your own contracts
        
        ## 🎯 Your Blend Contract Analysis
        
        Your Blend pool contract (`CAMKTT6LIXNOKZJVFI64EBEQE25UYAQZBTHDIQ4LEDJLTCM6YVME6IIY`) 
        should show:
        - Pool management functions (supply, borrow, withdraw)
        - Reserve configuration data
        - Interest rate calculations
        - Collateral and liability factors
        
        ═══════════════════════════════════════════════
        🎉 Happy Contract Debugging! 🎉
        """)
    }
}

// Quick access function
func printDebugGuide() {
    SmartContractDebugGuide.printUsageGuide()
} 