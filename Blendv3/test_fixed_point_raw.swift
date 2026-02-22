import Foundation

// Test with the provided data from the user
func testRawFixedPointCalculations() {
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
    
    do {
        // Calculate APR and APY
        let borrowAPR = try assetData.calculateBorrowAPR()
        let borrowAPY = try assetData.calculateBorrowAPY()
        let supplyAPR = try assetData.calculateSupplyAPR(backstopTakeRate: backstopTakeRate)
        let supplyAPY = try assetData.calculateSupplyAPY(backstopTakeRate: backstopTakeRate)
        
        // Print results
        print("Raw Data Test Results:")
        print("----------------------")
        print("Borrow APR: \(borrowAPR)%")
        print("Borrow APY: \(borrowAPY)%")
        print("Supply APR: \(supplyAPR)%")
        print("Supply APY: \(supplyAPY)%")
        
        // Verify results are close to expected values
        // Expected values based on JS SDK: borrow APR ≈ 0.913%
        assert(borrowAPR > 0.5 && borrowAPR < 1.5, "Borrow APR should be around 0.913%")
        
    } catch {
        print("Error in calculations: \(error)")
    }
}

// Run the test
testRawFixedPointCalculations() 