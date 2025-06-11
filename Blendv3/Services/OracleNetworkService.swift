import Foundation

/// Oracle network service - handles oracle data retrieval and price feeds
/// Uses NetworkService for networking and BlendParser for parsing
@MainActor
class OracleNetworkService: ObservableObject {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkService
    private let parser: BlendParser
    
    // MARK: - Properties
    
    @Published var latestPrices: [String: Double] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Initialization
    
    init(networkService: NetworkService = NetworkService(), parser: BlendParser = BlendParser.shared) {
        self.networkService = networkService
        self.parser = parser
    }
    
    // MARK: - Oracle Operations
    
    /// Get price for a specific asset
    func getPrice(for asset: String, oracleContract: String) async throws -> Double {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create arguments for contract call
            let assetArg = try parser.createSCVal(from: asset)
            let args = [assetArg]
            
            // Use NetworkService to get contract data
            let response = try await networkService.invokeContract(
                contractAddress: oracleContract,
                method: "get_price",
                args: args,
                sourceAccount: getDefaultKeyPair() // This would come from dependency injection in real app
            )
            
            // Use BlendParser to parse the result
            let result = try parser.parseSingleResult(from: response)
            let price = try parser.parseUInt64(from: result)
            
            let doublePrice = Double(price) / 1_000_000 // Assuming 6 decimal places
            
            // Update state
            DispatchQueue.main.async {
                self.latestPrices[asset] = doublePrice
                self.error = nil
            }
            
            return doublePrice
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    /// Get multiple asset prices in batch
    func getBatchPrices(for assets: [String], oracleContract: String) async throws -> [String: Double] {
        isLoading = true
        defer { isLoading = false }
        
        var prices: [String: Double] = [:]
        
        // Execute price requests concurrently
        try await withThrowingTaskGroup(of: (String, Double).self) { group in
            for asset in assets {
                group.addTask {
                    let price = try await self.getSinglePrice(for: asset, oracleContract: oracleContract)
                    return (asset, price)
                }
            }
            
            for try await (asset, price) in group {
                prices[asset] = price
            }
        }
        
        // Update state
        DispatchQueue.main.async {
            self.latestPrices.merge(prices) { _, new in new }
            self.error = nil
        }
        
        return prices
    }
    
    /// Get price data with timestamp
    func getPriceWithTimestamp(for asset: String, oracleContract: String) async throws -> (price: Double, timestamp: Date) {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let assetArg = try parser.createSCVal(from: asset)
            let args = [assetArg]
            
            let response = try await networkService.invokeContract(
                contractAddress: oracleContract,
                method: "get_price_data",
                args: args,
                sourceAccount: getDefaultKeyPair()
            )
            
            let result = try parser.parseSingleResult(from: response)
            let dataMap = try parser.parseMap(from: result)
            
            guard let priceScVal = dataMap["price"],
                  let timestampScVal = dataMap["timestamp"] else {
                throw OracleError.missingPriceData
            }
            
            let price = try parser.parseUInt64(from: priceScVal)
            let timestamp = try parser.parseUInt64(from: timestampScVal)
            
            let doublePrice = Double(price) / 1_000_000
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            
            return (doublePrice, date)
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    /// Subscribe to price updates via events
    func subscribeToOracleEvents(oracleContract: String, assets: [String]) async throws {
        do {
            // Get events from the oracle contract
            let eventsResponse = try await networkService.getEvents(
                contractAddress: oracleContract,
                topics: ["price_update"]
            )
            
            let events = parser.parseEvents(from: eventsResponse)
            
            for event in events {
                try processOracleEvent(event)
            }
            
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func getSinglePrice(for asset: String, oracleContract: String) async throws -> Double {
        let assetArg = try parser.createSCVal(from: asset)
        let args = [assetArg]
        
        let response = try await networkService.invokeContract(
            contractAddress: oracleContract,
            method: "get_price",
            args: args,
            sourceAccount: getDefaultKeyPair()
        )
        
        let result = try parser.parseSingleResult(from: response)
        let price = try parser.parseUInt64(from: result)
        
        return Double(price) / 1_000_000
    }
    
    private func processOracleEvent(_ event: Any) throws {
        // Process oracle price update events
        // This would parse the event data and update prices
        // Implementation depends on the specific event structure
    }
    
    private func getDefaultKeyPair() -> Any {
        // This should come from dependency injection or configuration
        // Placeholder for now
        fatalError("KeyPair should be provided through dependency injection")
    }
}

// MARK: - Error Types

enum OracleError: Error, LocalizedError {
    case missingPriceData
    case invalidOracleContract
    case priceNotAvailable(String)
    case oracleTimeout
    
    var errorDescription: String? {
        switch self {
        case .missingPriceData:
            return "Price data missing from oracle response"
        case .invalidOracleContract:
            return "Invalid oracle contract address"
        case .priceNotAvailable(let asset):
            return "Price not available for asset: \(asset)"
        case .oracleTimeout:
            return "Oracle request timed out"
        }
    }
}