import SwiftUI
import Foundation

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var testResults: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Financial Calculations Test")
                    .font(.title)
                    .padding()
                
                Button("Run Test") {
                    runTest()
                }
                .padding()
                
                Text(testResults)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
    }
    
    func runTest() {
        // Create a BlendAssetData instance with the raw values from the provided data
        let assetData = BlendAssetData(
            assetId: "2022d56e0aba64516f6e62604d296232be864ffdfb84d58613e7423cace02b28",
            scalar: 10_000_000, // 1e7
            decimals: 7,
            enabled: true,
            index: 3,
            cFactor: 9_500_000, // 0.95 as raw fixed-point
            lFactor: 9_500_000, // 0.95 as raw fixed-point
            maxUtil: 9_500_000, // 0.95 as raw fixed-point
            rBase: 5_000, // 0.0005 as raw fixed-point
            rOne: 300_000, // 0.03 as raw fixed-point
            rTwo: 1_000_000, // 0.1 as raw fixed-point
            rThree: 10_000_000, // 1.0 as raw fixed-point
            reactivity: 100, // 0.00001 as raw fixed-point
            supplyCap: Decimal(string: "92233720368547758070000000000000000000000000000000000000000000000000000000000000000")!,
            utilTarget: 7_500_000, // 0.75 as raw fixed-point
            totalSupplied: 253_242_521_580, // 25324.252158 * 1e7
            totalBorrowed: 189_569_995_217, // 18956.9995217 * 1e7
            borrowRate: 1_001_278_311_027, // Raw from chain
            supplyRate: 0,
            dRate: 1_002_192_732_109, // Raw from chain (SCALAR_12)
            backstopCredit: 21_705_254, // 2.1705254 * 1e7
            irModifier: 2_995_478, // 0.2995478 as raw fixed-point
            lastUpdate: Date(timeIntervalSince1970: 1718328188), // 2025-06-14 03:23:08 +0000
            pricePerToken: 0
        )
        
        // Set backstopTakeRate to 0.1 (10%)
        let backstopTakeRate: Decimal = 1_000_000 // 0.1 as raw fixed-point (10%)
        
        var results = "Raw Data Test Results:\n"
        results += "----------------------\n"
        
        do {
            // Calculate utilization rate
            let utilization = try assetData.calculateUtilizationRate(usingAccruedInterest: true)
            results += "Utilization: \(utilization * 100)%\n"
            
            // Calculate kinked interest rate
            let kinkedRate = try assetData.calculateKinkedInterestRate(utilization: utilization)
            results += "Kinked Rate: \(kinkedRate * 100)%\n"
            
            // Calculate APR and APY
            let borrowAPR = try assetData.calculateBorrowAPR()
            let borrowAPY = try assetData.calculateBorrowAPY()
            let supplyAPR = try assetData.calculateSupplyAPR(backstopTakeRate: backstopTakeRate)
            let supplyAPY = try assetData.calculateSupplyAPY(backstopTakeRate: backstopTakeRate)
            
            results += "Borrow APR: \(borrowAPR)%\n"
            results += "Borrow APY: \(borrowAPY)%\n"
            results += "Supply APR: \(supplyAPR)%\n"
            results += "Supply APY: \(supplyAPY)%\n"
            
            // Add raw data for reference
            results += "\nRaw Data:\n"
            results += "totalSupplied: \(assetData.totalSupplied)\n"
            results += "totalBorrowed: \(assetData.totalBorrowed)\n"
            results += "dRate: \(assetData.dRate)\n"
            results += "Human-readable values:\n"
            results += "totalSupplied (human): \(assetData.suppliedHuman)\n"
            results += "totalBorrowed (human): \(assetData.borrowedHuman)\n"
            results += "dRate (human): \(FixedMath.toFloat(value: assetData.dRate, decimals: 12))\n"
            
        } catch {
            results += "Error in calculations: \(error)"
        }
        
        testResults = results
    }
} 