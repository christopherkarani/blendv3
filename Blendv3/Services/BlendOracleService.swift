import Foundation
import stellarsdk
import os

// MARK: - Data Extensions (using existing extension from BlendUSDCVault)

// MARK: - Soroban Contract Operations

/// Contract call parameters for real Soroban operations
struct ContractCallParams {
    let contractId: String
    let functionName: String
    let functionArguments: [SCValXDR]
    
    init(contractId: String, functionName: String, functionArguments: [SCValXDR]) {
        self.contractId = contractId
        self.functionName = functionName
        self.functionArguments = functionArguments
    }
}

/// Oracle service implementation with correct Blend oracle functions
public final class BlendOracleService: BlendOracleServiceProtocol {
    
    // MARK: - Properties
    
    private let networkService: NetworkServiceProtocol
    private let cacheService: CacheServiceProtocol
    
    // Debug logging
    private let debugLogger = DebugLogger(subsystem: "com.blendv3.oracle", category: "OracleService")
    
    // Cache TTL configurations
    private let priceCacheTTL: TimeInterval = 300 // 5 minutes
    private let decimalsCacheTTL: TimeInterval = 3600 // 1 hour
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    // Oracle contract configuration
    private let oracleAddress = BlendUSDCConstants.Testnet.oracle
    private let rpcUrl = BlendUSDCConstants.RPC.testnet
    private let network = Network.testnet
    
    // MARK: - Initialization
    
    public init(networkService: NetworkServiceProtocol, cacheService: CacheServiceProtocol) {
        self.networkService = networkService
        self.cacheService = cacheService
        
        // Enhanced initialization logging
        BlendLogger.info("🔮 Oracle service initializing...", category: BlendLogger.oracle)
        BlendLogger.info("🔮 Oracle address: \(oracleAddress)", category: BlendLogger.oracle)
        BlendLogger.info("🔮 RPC URL: \(rpcUrl)", category: BlendLogger.oracle)
        BlendLogger.info("🔮 Network: \(network)", category: BlendLogger.oracle)
        BlendLogger.info("🔮 Price cache TTL: \(priceCacheTTL)s", category: BlendLogger.oracle)
        BlendLogger.info("🔮 Decimals cache TTL: \(decimalsCacheTTL)s", category: BlendLogger.oracle)
        BlendLogger.info("🔮 Max retries: \(maxRetries)", category: BlendLogger.oracle)
        BlendLogger.info("🔮 Retry delay: \(retryDelay)s", category: BlendLogger.oracle)
        BlendLogger.info("🔮 ✅ Oracle service initialized successfully", category: BlendLogger.oracle)
        
        // Also log to debug logger for easier debugging
        debugLogger.info("🔮 Oracle service initialized with address: \(oracleAddress)")
        debugLogger.info("🔮 Using RPC: \(rpcUrl)")
    }
    
    // MARK: - BlendOracleServiceProtocol
    
    public func getPrices(assets: [String]) async throws -> [String: PriceData] {
        BlendLogger.info("🔮 📊 Fetching prices for \(assets.count) assets", category: BlendLogger.oracle)
        debugLogger.info("🔮 📊 getPrices called with assets: \(assets.joined(separator: ", "))")
        
        return try await measurePerformance(operation: "getPrices", category: BlendLogger.oracle) {
            // Check cache first
            var cachedPrices: [String: PriceData] = [:]
            var assetsToFetch: [String] = []
            
            BlendLogger.info("🔮 🗄️ Checking cache for existing prices...", category: BlendLogger.oracle)
            debugLogger.info("🔮 🗄️ Checking cache for \(assets.count) assets")
            
            for asset in assets {
                let cacheKey = CacheKeys.oraclePrice(asset: asset)
                if let cachedPrice = cacheService.get(cacheKey, type: PriceData.self),
                   !cachedPrice.isStale(maxAge: priceCacheTTL) {
                    cachedPrices[asset] = cachedPrice
                    let symbol = getAssetSymbol(for: asset)
                    BlendLogger.debug("🔮 ✅ Using cached price for \(symbol): $\(cachedPrice.priceInUSD)", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ✅ Cache hit for \(symbol): $\(cachedPrice.priceInUSD)")
                } else {
                    assetsToFetch.append(asset)
                    let symbol = getAssetSymbol(for: asset)
                    BlendLogger.debug("🔮 ❌ Cache miss for \(symbol), will fetch", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ❌ Cache miss for \(symbol)")
                }
            }
            
            BlendLogger.info("🔮 📈 Cache results: \(cachedPrices.count) cached, \(assetsToFetch.count) to fetch", category: BlendLogger.oracle)
            debugLogger.info("🔮 📈 Assets to fetch: \(assetsToFetch.map { getAssetSymbol(for: $0) }.joined(separator: ", "))")
            
            // Fetch missing prices using lastprice() for each asset
            let fetchedPrices = try await fetchPricesUsingLastPrice(assets: assetsToFetch)
            
            BlendLogger.info("🔮 ✅ Fetched \(fetchedPrices.count) new prices", category: BlendLogger.oracle)
            debugLogger.info("🔮 ✅ Successfully fetched prices for: \(fetchedPrices.keys.map { getAssetSymbol(for: $0) }.joined(separator: ", "))")
            
            // Cache new prices
            for (asset, priceData) in fetchedPrices {
                let cacheKey = CacheKeys.oraclePrice(asset: asset)
                cacheService.set(priceData, key: cacheKey, ttl: priceCacheTTL)
                let symbol = getAssetSymbol(for: asset)
                BlendLogger.debug("🔮 💾 Cached price for \(symbol): $\(priceData.priceInUSD)", category: BlendLogger.oracle)
                debugLogger.info("🔮 💾 Cached price for \(symbol)")
            }
            
            // Merge cached and fetched prices
            let allPrices = cachedPrices.merging(fetchedPrices) { cached, fetched in
                BlendLogger.warning("🔮 ⚠️ Price conflict for asset, using fetched price", category: BlendLogger.oracle)
                debugLogger.warning("🔮 ⚠️ Price conflict detected, using fetched price")
                return fetched
            }
            
            BlendLogger.info("🔮 🎯 Successfully retrieved prices for \(allPrices.count) assets", category: BlendLogger.oracle)
            debugLogger.info("🔮 🎯 Final result: \(allPrices.count) prices returned")
            
            // Log final price summary
            for (asset, priceData) in allPrices {
                let symbol = getAssetSymbol(for: asset)
                debugLogger.info("🔮 💰 \(symbol): $\(priceData.priceInUSD) (age: \(Date().timeIntervalSince(priceData.timestamp))s)")
            }
            
            return allPrices
        }
    }

    public func getPrice(asset: String) async throws -> PriceData {
        let symbol = getAssetSymbol(for: asset)
        BlendLogger.info("🔮 🎯 Fetching single price for asset: \(symbol) (\(asset))", category: BlendLogger.oracle)
        debugLogger.info("🔮 🎯 getPrice called for single asset: \(symbol)")
        
        // Use lastprice() function for single asset
        do {
            if let priceData = try await fetchSinglePriceUsingLastPrice(asset: asset) {
                BlendLogger.info("🔮 ✅ Successfully fetched price for \(symbol): $\(priceData.priceInUSD)", category: BlendLogger.oracle)
                debugLogger.info("🔮 ✅ Single price fetch successful for \(symbol): $\(priceData.priceInUSD)")
                return priceData
            } else {
                BlendLogger.error("🔮 ❌ No price data available for \(symbol)", category: BlendLogger.oracle)
                debugLogger.error("🔮 ❌ fetchSinglePriceUsingLastPrice returned nil for \(symbol)")
                throw OracleError.priceNotAvailable(asset: asset, reason: "Oracle returned None for lastprice() call")
            }
        } catch {
            BlendLogger.error("🔮 💥 Failed to fetch price for \(symbol)", error: error, category: BlendLogger.oracle)
            debugLogger.error("🔮 💥 getPrice failed for \(symbol): \(error.localizedDescription)")
            throw error
        }
    }

    public func getOracleDecimals() async throws -> Int {
        BlendLogger.info("Fetching oracle decimals", category: BlendLogger.oracle)
        
        let cacheKey = "oracle_decimals"
        if let cachedDecimals = cacheService.get(cacheKey, type: Int.self) {
            BlendLogger.info("Using cached oracle decimals: \(cachedDecimals)", category: BlendLogger.oracle)
            return cachedDecimals
        }
        
        return try await measurePerformance(operation: "getOracleDecimals", category: BlendLogger.oracle) {
            let decimals = try await fetchOracleDecimals()
            cacheService.set(decimals, key: cacheKey, ttl: decimalsCacheTTL)
            BlendLogger.info("Fetched and cached oracle decimals: \(decimals)", category: BlendLogger.oracle)
            return decimals
        }
    }
    
    // MARK: - Oracle-specific Methods
    
    /// Get price at specific timestamp using price() function
    public func getPrice(asset: String, timestamp: UInt64) async throws -> PriceData? {
        BlendLogger.info("Fetching price for asset: \(asset) at timestamp: \(timestamp)", category: BlendLogger.oracle)
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            // Create Asset::Stellar(address) parameter
            let assetParam = try self.createAssetParameter(contractAddress: asset)
            let timestampParam = SCValXDR.u64(timestamp)
            
            // Create contract call for price() function
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "price",
                functionArguments: [assetParam, timestampParam]
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            // Parse Option<PriceData> response
            return try self.parseOptionalPriceData(from: response, assetId: asset)
        }
    }
    
    /// Get multiple price records using prices() function
    public func getPrices(asset: String, records: UInt32) async throws -> [PriceData] {
        BlendLogger.info("Fetching \(records) price records for asset: \(asset)", category: BlendLogger.oracle)
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            // Create Asset::Stellar(address) parameter
            let assetParam = try self.createAssetParameter(contractAddress: asset)
            let recordsParam = SCValXDR.u32(records)
            
            // Create contract call for prices() function
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "prices",
                functionArguments: [assetParam, recordsParam]
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            // Parse Option<Vec<PriceData>> response
            return try self.parseOptionalPriceDataVector(from: response, assetId: asset)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchPricesUsingLastPrice(assets: [String]) async throws -> [String: PriceData] {
        BlendLogger.info("🔮 🚀 Starting fetchPricesUsingLastPrice for \(assets.count) assets", category: BlendLogger.oracle)
        debugLogger.info("🔮 🚀 fetchPricesUsingLastPrice called with: \(assets.map { getAssetSymbol(for: $0) }.joined(separator: ", "))")
        
        var prices: [String: PriceData] = [:]
        var errors: [String: Error] = [:]
        
        BlendLogger.info("🔮 ⚡ Starting concurrent price fetching...", category: BlendLogger.oracle)
        debugLogger.info("🔮 ⚡ Creating task group for concurrent fetching")
        
        // Fetch prices concurrently
        await withTaskGroup(of: (String, Result<PriceData?, Error>).self) { [self] group in
            for asset in assets {
                group.addTask { [self] in
                    let symbol = getAssetSymbol(for: asset)
                    self.debugLogger.info("🔮 🔄 Starting fetch for \(symbol)")
                    do {
                        let result = try await self.fetchSinglePriceUsingLastPrice(asset: asset)
                        self.debugLogger.info("🔮 ✅ Fetch completed for \(symbol)")
                        return (asset, .success(result))
                    } catch {
                        self.debugLogger.error("🔮 ❌ Fetch failed for \(symbol): \(error.localizedDescription)")
                        return (asset, .failure(error))
                    }
                }
            }
            
            BlendLogger.info("🔮 📥 Processing task results...", category: BlendLogger.oracle)
            debugLogger.info("🔮 📥 Waiting for task group results")
            
            for await (asset, result) in group {
                let symbol = getAssetSymbol(for: asset)
                
                switch result {
                case .success(let priceData):
                    if let priceData = priceData {
                        prices[asset] = priceData
                        BlendLogger.info("🔮 ✅ Price received for \(symbol): $\(priceData.priceInUSD)", category: BlendLogger.oracle)
                        debugLogger.info("🔮 ✅ Successfully processed price for \(symbol): $\(priceData.priceInUSD)")
                        BlendLogger.oraclePrice(asset: asset, price: priceData.price, timestamp: priceData.timestamp, isStale: false)
                    } else {
                        BlendLogger.warning("🔮 ⚠️ No price data available for asset: \(symbol)", category: BlendLogger.oracle)
                        debugLogger.warning("🔮 ⚠️ Received nil price data for \(symbol)")
                    }
                case .failure(let error):
                    errors[asset] = error
                    BlendLogger.error("🔮 ❌ Failed to fetch price for asset: \(symbol)", error: error, category: BlendLogger.oracle)
                    debugLogger.error("🔮 ❌ Error processing \(symbol): \(error.localizedDescription)")
                }
            }
        }
        
        BlendLogger.info("🔮 📊 Fetch results: \(prices.count) successful, \(errors.count) failed", category: BlendLogger.oracle)
        debugLogger.info("🔮 📊 Final tally - Success: \(prices.count), Errors: \(errors.count)")
        
        // Log detailed results
        if !prices.isEmpty {
            debugLogger.info("🔮 ✅ Successful fetches:")
            for (asset, priceData) in prices {
                let symbol = getAssetSymbol(for: asset)
                debugLogger.info("🔮   - \(symbol): $\(priceData.priceInUSD)")
            }
        }
        
        if !errors.isEmpty {
            debugLogger.error("🔮 ❌ Failed fetches:")
            for (asset, error) in errors {
                let symbol = getAssetSymbol(for: asset)
                debugLogger.error("🔮   - \(symbol): \(error.localizedDescription)")
            }
        }
        
        // If we have some prices, return them; otherwise throw the first error
        if !prices.isEmpty {
            BlendLogger.info("🔮 🎯 Successfully fetched \(prices.count) prices using lastprice()", category: BlendLogger.oracle)
            debugLogger.info("🔮 🎯 Returning \(prices.count) successful prices")
            if !errors.isEmpty {
                BlendLogger.warning("🔮 ⚠️ Failed to fetch prices for \(errors.count) assets", category: BlendLogger.oracle)
                debugLogger.warning("🔮 ⚠️ Some assets failed but continuing with partial results")
            }
            return prices
        } else if let firstError = errors.values.first {
            BlendLogger.error("🔮 💥 All price fetches failed, throwing first error", category: BlendLogger.oracle)
            debugLogger.error("🔮 💥 No successful fetches, throwing error: \(firstError.localizedDescription)")
            
            // Wrap the error with more context
            if let oracleError = firstError as? OracleError {
                throw oracleError
            } else {
                throw OracleError.networkError(firstError, context: "All \(assets.count) price fetches failed")
            }
        } else {
            BlendLogger.error("🔮 💥 No data available and no errors recorded", category: BlendLogger.oracle)
            debugLogger.error("🔮 💥 Unexpected state: no prices and no errors")
            throw OracleError.noDataAvailable(context: "No prices fetched and no errors recorded for \(assets.count) assets")
        }
    }
    
    private func fetchSinglePriceUsingLastPrice(asset: String) async throws -> PriceData? {
        let asssetContract = normalizeContractAddress(asset) ?? asset
        let symbol = getAssetSymbol(for: asssetContract)
        BlendLogger.debug("🔮 🎯 Starting fetchSinglePriceUsingLastPrice for asset: \(symbol)", category: BlendLogger.oracle)
        debugLogger.info("🔮 🎯 fetchSinglePriceUsingLastPrice called for \(symbol) (\(asset))")
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) { [self] in
            BlendLogger.debug("🔮 🔄 Creating Soroban server connection...", category: BlendLogger.oracle)
            debugLogger.info("🔮 🔄 Connecting to Soroban RPC: \(self.rpcUrl)")
            
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            BlendLogger.debug("🔮 📝 Creating Asset::Stellar parameter for \(symbol)", category: BlendLogger.oracle)
            debugLogger.info("🔮 📝 Creating Asset::Stellar parameter for \(symbol)")
            
            // Create Asset::Stellar(address) parameter
            let assetParam = try self.createAssetParameter(contractAddress: asset)
            
            BlendLogger.debug("🔮 📞 Calling lastprice() function for \(symbol)", category: BlendLogger.oracle)
            debugLogger.info("🔮 📞 Contract call details:")
            debugLogger.info("🔮   - Contract: \(self.oracleAddress)")
            debugLogger.info("🔮   - Function: lastprice")
            debugLogger.info("🔮   - Asset: \(symbol) (\(asset))")
            
            // Create contract call operation
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "lastprice",
                functionArguments: [assetParam]
            )
            
            BlendLogger.debug("🔮 🚀 Starting contract simulation for lastprice(\(symbol))", category: BlendLogger.oracle)
            debugLogger.info("🔮 🚀 Starting contract simulation for lastprice(\(symbol))")
            
            // Simulate the contract call
            let result = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            BlendLogger.debug("🔮 📥 Contract call completed for \(symbol), parsing response", category: BlendLogger.oracle)
            debugLogger.info("🔮 📥 Contract call completed for \(symbol), parsing response")
            
            // Parse the result as Option<PriceData>
            if let priceData = try self.parseOptionalPriceData(from: result, assetId: asset) {
                BlendLogger.debug("🔮 ✅ Successfully fetched price for \(symbol): $\(priceData.priceInUSD)", category: BlendLogger.oracle)
                debugLogger.info("🔮 ✅ Price parsing successful for \(symbol):")
                debugLogger.info("🔮   - Price: $\(priceData.priceInUSD)")
                debugLogger.info("🔮   - Timestamp: \(priceData.timestamp)")
                debugLogger.info("🔮   - Age: \(Date().timeIntervalSince(priceData.timestamp))s")
                return priceData
            } else {
                BlendLogger.warning("🔮 ⚠️ No price data available for \(symbol)", category: BlendLogger.oracle)
                debugLogger.warning("🔮 ⚠️ parseOptionalPriceData returned nil for \(symbol)")
                return nil
            }
        }
    }
    
    private func fetchOracleDecimals() async throws -> Int {
        BlendLogger.debug("Fetching oracle decimals from contract", category: BlendLogger.oracle)
        
        return try await withRetry(maxAttempts: self.maxRetries, delay: self.retryDelay) {
            let sorobanServer = SorobanServer(endpoint: self.rpcUrl)
            
            // Create contract call for decimals() function (if it exists)
            let contractCall = ContractCallParams(
                contractId: self.oracleAddress,
                functionName: "decimals",
                functionArguments: []
            )
            
            let response = try await self.simulateContractCall(sorobanServer: sorobanServer, contractCall: contractCall)
            
            // Parse decimals from response
            if case .u32(let decimals) = response {
                return Int(decimals)
            } else {
                // Default to 7 decimals if decimals() function doesn't exist
                BlendLogger.warning("Oracle decimals() function not available, using default 7", category: BlendLogger.oracle)
                return 7
            }
        }
    }
    
    /// Simulate contract call and return result using real Soroban RPC
    private func simulateContractCall(sorobanServer: SorobanServer, contractCall: ContractCallParams) async throws -> SCValXDR {
        BlendLogger.info("🔮 🌐 Making REAL Soroban contract call: \(contractCall.functionName) for contract: \(contractCall.contractId)", category: BlendLogger.oracle)
        debugLogger.info("🔮 🌐 Real contract simulation starting...")
        
        do {
            // Create real InvokeHostFunctionOperation using Stellar SDK
            let operation = try InvokeHostFunctionOperation.forInvokingContract(
                contractId: contractCall.contractId,
                functionName: contractCall.functionName,
                functionArguments: contractCall.functionArguments
            )
            
            // Create a dummy source account for simulation (not needed for simulation)
            let sourceKeyPair = try KeyPair.generateRandomKeyPair()
            let sourceAccount = Account(keyPair: sourceKeyPair, sequenceNumber: 0)
            
            // Build transaction for simulation
            let transaction = try Transaction(
                sourceAccount: sourceAccount,
                operations: [operation],
                memo: Memo.none
            )
            
            BlendLogger.debug("🔮 📡 Sending transaction to Soroban RPC for simulation...", category: BlendLogger.oracle)
            debugLogger.info("🔮 📡 Calling sorobanServer.simulateTransaction...")
            
            // Create simulation request
            let simulateRequest = SimulateTransactionRequest(transaction: transaction)
            
            // Simulate the transaction on the real Soroban network
            let simulationResponse = await sorobanServer.simulateTransaction(simulateTxRequest: simulateRequest)
            
            BlendLogger.debug("🔮 📥 Received simulation response from Soroban", category: BlendLogger.oracle)
            debugLogger.info("🔮 📥 Simulation response received, parsing...")
            
            // Handle the simulation response enum
            switch simulationResponse {
            case .success(let response):
                BlendLogger.debug("🔮 ✅ Simulation successful", category: BlendLogger.oracle)
                
                // Extract return value from successful response
                // Check if response has results array and get the first result
                guard let results = response.results, 
                      let firstResult = results.first else {
                    BlendLogger.error("🔮 ❌ No return value in simulation result", category: BlendLogger.oracle)
                    let details = "Simulation response missing results array or first result"
                    throw OracleError.invalidResponse(details: details, rawData: String(describing: response))
                }
                
                // Parse the XDR string to SCValXDR
                let xdrString = firstResult.xdr
                guard let retval = try? SCValXDR(xdr: xdrString) else {
                    BlendLogger.error("🔮 ❌ Failed to parse XDR response: \(xdrString)", category: BlendLogger.oracle)
                    let details = "Failed to parse XDR string to SCValXDR"
                    throw OracleError.invalidResponse(details: details, rawData: xdrString)
                }
                
                BlendLogger.info("🔮 ✅ Successfully received real contract response", category: BlendLogger.oracle)
                debugLogger.info("🔮 ✅ Real contract call completed successfully")
                debugLogger.info("🔮 📊 Return value type: \(String(describing: type(of: retval)))")
                
                return retval
                
            case .failure(let error):
                BlendLogger.error("🔮 ❌ Simulation failed with error: \(error)", category: BlendLogger.oracle)
                let context = "Contract: \(contractCall.contractId), Function: \(contractCall.functionName)"
                throw OracleError.simulationError(transactionHash: nil, error: "\(error) - \(context)")
            }
            
        } catch let error as SorobanRpcRequestError {
            BlendLogger.error("🔮 💥 Soroban RPC request failed", error: error, category: BlendLogger.oracle)
            debugLogger.error("🔮 💥 SorobanRpcRequestError: \(error.localizedDescription)")
            throw OracleError.rpcError(endpoint: self.rpcUrl, statusCode: nil, message: error.localizedDescription)
            
        } catch let oracleError as OracleError {
            // Re-throw oracle errors as-is
            throw oracleError
            
        } catch {
            BlendLogger.error("🔮 💥 Contract simulation failed", error: error, category: BlendLogger.oracle)
            debugLogger.error("🔮 💥 General error: \(error.localizedDescription)")
            let context = "Contract: \(contractCall.contractId), Function: \(contractCall.functionName)"
            throw OracleError.networkError(error, context: context)
        }
    }
    

    
    /// Create Asset::Stellar(contract_address) parameter for oracle calls
    /// Based on Blend Protocol documentation, Asset::Stellar is represented as an enum variant
    private func createAssetParameter(contractAddress: String) throws -> SCValXDR {
        BlendLogger.debug("🔮 📝 Creating asset parameter for: \(contractAddress)", category: BlendLogger.oracle)
        debugLogger.info("🔮 📝 createAssetParameter called with: \(contractAddress)")
        
        // Normalize the contract address to ensure it's in proper Soroban format
        let normalizedAddress = normalizeContractAddress(contractAddress) ?? contractAddress
        BlendLogger.debug("🔮 📝 Normalized address: \(normalizedAddress)", category: BlendLogger.oracle)
        debugLogger.info("🔮 📝 Normalized address: \(normalizedAddress)")
        
        // Create Asset::Stellar(address) enum variant
        let contractAddressXdr = try SCAddressXDR(contractId: normalizedAddress)
        let addressVal = SCValXDR.address(contractAddressXdr)
        
        // Based on Blend Protocol documentation and Stellar SDK patterns,
        // Asset::Stellar(address) should be represented as a vector with symbol and address
        // This follows the Soroban enum representation pattern
        let assetVariant = SCValXDR.vec([
            SCValXDR.symbol("Stellar"),
            addressVal
        ])
        
        BlendLogger.debug("🔮 ✅ Asset parameter created successfully", category: BlendLogger.oracle)
        debugLogger.info("🔮 ✅ Asset parameter created for \(getAssetSymbol(for: contractAddress))")
        
        return assetVariant
    }
    
    /// Normalize contract address to ensure proper Soroban format
    /// Converts hex contract IDs to proper Stellar contract addresses if needed
    private func normalizeContractAddress(_ address: String) -> String? {
        // If the address is already in proper Stellar format (starts with 'C' and is 56 chars), return as-is
        if StellarContractID.isStrKeyContract(address) {
            return address
        }
        return try? StellarContractID.decode(strKey: address)
    }
    
    /// Parse Option<PriceData> from oracle response
    private func parseOptionalPriceData(from resultXdr: SCValXDR, assetId: String) throws -> PriceData? {
        let symbol = getAssetSymbol(for: assetId)
        BlendLogger.debug("🔮 📊 Parsing Option<PriceData> for asset: \(symbol)", category: BlendLogger.oracle)
        debugLogger.info("🔮 📊 parseOptionalPriceData called for \(symbol) (\(assetId))")
        debugLogger.info("🔮 📊 Raw XDR type: \(String(describing: type(of: resultXdr)))")
        
        // Based on Blend Protocol documentation, Option<T> in Soroban can be:
        // - None: represented as void/null
        // - Some(T): represented as an instance with the value
        
        switch resultXdr {
        case .void:
            // None case - no price data available
            BlendLogger.debug("🔮 ❌ No price data available (None) for asset: \(symbol)", category: BlendLogger.oracle)
            debugLogger.info("🔮 ❌ Oracle returned None for \(symbol)")
            return nil
            
        case .vec(let vecOptional):
            // Some(PriceData) case - might be wrapped in a vector
            guard let vec = vecOptional, !vec.isEmpty else {
                BlendLogger.debug("🔮 ❌ Empty vector for \(symbol)", category: BlendLogger.oracle)
                return nil
            }
            
            // Try to parse the first element as PriceData
            BlendLogger.debug("🔮 ✅ Found vector with \(vec.count) elements for \(symbol), parsing first...", category: BlendLogger.oracle)
            debugLogger.info("🔮 ✅ Vector found, parsing first element as PriceData")
            return try parseWrappedPriceData(from: vec[0], assetId: assetId)
            
        case .map(let mapOptional):
            // Direct PriceData struct (no Option wrapper)
            guard let map = mapOptional else {
                BlendLogger.error("🔮 💥 Invalid map response for \(symbol)", category: BlendLogger.oracle)
                debugLogger.error("🔮 💥 Map is nil for \(symbol)")
                let details = "Map is nil in direct PriceData response"
                throw OracleError.invalidResponse(details: details, rawData: String(describing: resultXdr))
            }
            
            BlendLogger.debug("🔮 ✅ Found direct PriceData map for \(symbol), parsing...", category: BlendLogger.oracle)
            debugLogger.info("🔮 ✅ Parsing direct PriceData struct for \(symbol)")
            return try parsePriceDataStruct(from: map, assetId: assetId)
            
        case .i128(let priceValue):
            // Simple price value (just the price as i128, no timestamp)
            BlendLogger.debug("🔮 💰 Found simple price value for \(symbol)", category: BlendLogger.oracle)
            debugLogger.info("🔮 💰 Parsing simple i128 price for \(symbol)")
            let price = parseI128ToDecimal(priceValue)
            return PriceData(
                price: price,
                timestamp: Date(), // Use current time if no timestamp provided
                assetId: assetId,
                decimals: 7
            )
            
        default:
            BlendLogger.warning("🔮 ⚠️ Unexpected oracle response format for asset: \(symbol)", category: BlendLogger.oracle)
            debugLogger.warning("🔮 ⚠️ Unexpected response format for \(symbol): \(resultXdr)")
            debugLogger.warning("🔮 ⚠️ XDR details: \(resultXdr)")
            let details = "Unexpected XDR type: \(String(describing: type(of: resultXdr)))"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: resultXdr))
        }
    }
    
    /// Parse Option<Vec<PriceData>> from oracle response
    private func parseOptionalPriceDataVector(from resultXdr: SCValXDR, assetId: String) throws -> [PriceData] {
        BlendLogger.debug("Parsing Option<Vec<PriceData>> for asset: \(assetId)", category: BlendLogger.oracle)
        
        switch resultXdr {
        case .void:
            // None case - no price data available
            BlendLogger.debug("No price data available (None) for asset: \(assetId)", category: BlendLogger.oracle)
            return []
            
        case .vec(let vecOptional):
            // Some(Vec<PriceData>) case
            guard let vec = vecOptional else {
                let details = "Vector is nil in Option<Vec<PriceData>> response"
                throw OracleError.invalidResponse(details: details, rawData: String(describing: resultXdr))
            }
            
            var priceDataArray: [PriceData] = []
            for item in vec {
                if case .map(let mapOptional) = item, let map = mapOptional {
                    let priceData = try parsePriceDataStruct(from: map, assetId: assetId)
                    priceDataArray.append(priceData)
                }
            }
            
            BlendLogger.debug("Parsed \(priceDataArray.count) price records for asset: \(assetId)", category: BlendLogger.oracle)
            return priceDataArray
            
        default:
            BlendLogger.warning("Unexpected oracle response format for price vector: \(assetId)", category: BlendLogger.oracle)
            let details = "Unexpected XDR type for price vector: \(String(describing: type(of: resultXdr)))"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: resultXdr))
        }
    }
    
    /// Parse wrapped PriceData from Option<PriceData> instance
    private func parseWrappedPriceData(from value: SCValXDR, assetId: String) throws -> PriceData? {
        let symbol = getAssetSymbol(for: assetId)
        BlendLogger.debug("🔮 🔍 Parsing wrapped PriceData for \(symbol)", category: BlendLogger.oracle)
        debugLogger.info("🔮 🔍 parseWrappedPriceData called for \(symbol)")
        
        switch value {
        case .map(let mapOptional):
            guard let map = mapOptional else {
                BlendLogger.error("🔮 💥 Invalid wrapped map for \(symbol)", category: BlendLogger.oracle)
                let details = "Map is nil in wrapped PriceData"
                throw OracleError.invalidResponse(details: details, rawData: String(describing: value))
            }
            return try parsePriceDataStruct(from: map, assetId: assetId)
            
        case .i128(let priceValue):
            // Simple price value
            let price = parseI128ToDecimal(priceValue)
            return PriceData(
                price: price,
                timestamp: Date(),
                assetId: assetId,
                decimals: 7
            )
            
        default:
            BlendLogger.warning("🔮 ⚠️ Unexpected wrapped value type for \(symbol): \(value)", category: BlendLogger.oracle)
            let details = "Unexpected wrapped value type: \(String(describing: type(of: value)))"
            throw OracleError.invalidResponse(details: details, rawData: String(describing: value))
        }
    }
    
    /// Parse PriceData struct from map
    private func parsePriceDataStruct(from map: [SCMapEntryXDR], assetId: String) throws -> PriceData {
        let symbol = getAssetSymbol(for: assetId)
        BlendLogger.debug("🔮 🔍 Parsing PriceData struct for \(symbol) with \(map.count) fields", category: BlendLogger.oracle)
        debugLogger.info("🔮 🔍 parsePriceDataStruct called for \(symbol)")
        
        var price: Decimal?
        var timestamp: Date?
        
        for entry in map {
            if case .symbol(let key) = entry.key {
                debugLogger.info("🔮 🔑 Processing field: \(key)")
                
                switch key {
                case "price":
                    if case .i128(let priceValue) = entry.val {
                        // Convert i128 to Decimal
                        price = parseI128ToDecimal(priceValue)
                        BlendLogger.debug("🔮 💰 Parsed price for \(symbol): \(price!)", category: BlendLogger.oracle)
                        debugLogger.info("🔮 💰 Price field parsed: \(price!)")
                    } else {
                        BlendLogger.warning("🔮 ⚠️ Invalid price field type for \(symbol)", category: BlendLogger.oracle)
                        debugLogger.warning("🔮 ⚠️ Price field is not i128: \(entry.val)")
                    }
                case "timestamp":
                    if case .u64(let timestampValue) = entry.val {
                        timestamp = Date(timeIntervalSince1970: TimeInterval(timestampValue))
                        BlendLogger.debug("🔮 ⏰ Parsed timestamp for \(symbol): \(timestamp!)", category: BlendLogger.oracle)
                        debugLogger.info("🔮 ⏰ Timestamp field parsed: \(timestamp!)")
                    } else {
                        BlendLogger.warning("🔮 ⚠️ Invalid timestamp field type for \(symbol)", category: BlendLogger.oracle)
                        debugLogger.warning("🔮 ⚠️ Timestamp field is not u64: \(entry.val)")
                    }
                default:
                    BlendLogger.debug("🔮 ❓ Unknown PriceData field: \(key) for \(symbol)", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ❓ Ignoring unknown field: \(key)")
                }
            } else {
                BlendLogger.warning("🔮 ⚠️ Non-symbol key in PriceData for \(symbol)", category: BlendLogger.oracle)
                debugLogger.warning("🔮 ⚠️ Non-symbol key: \(entry.key)")
            }
        }
        
        guard let finalPrice = price, let finalTimestamp = timestamp else {
            BlendLogger.error("🔮 💥 Missing required PriceData fields for asset: \(symbol)", category: BlendLogger.oracle)
            debugLogger.error("🔮 💥 Missing fields - price: \(price != nil), timestamp: \(timestamp != nil)")
            
            let missingFields = [
                price == nil ? "price" : nil,
                timestamp == nil ? "timestamp" : nil
            ].compactMap { $0 }
            
            let details = "Missing required fields: \(missingFields.joined(separator: ", "))"
            throw OracleError.parsingError(field: missingFields.first ?? "unknown", expectedType: "required", actualType: "missing")
        }
        
        let priceData = PriceData(
            price: finalPrice,
            timestamp: finalTimestamp,
            assetId: assetId,
            decimals: 7 // Default to 7 decimals for Blend
        )
        
        BlendLogger.debug("🔮 ✅ Successfully parsed PriceData for \(symbol): price=\(finalPrice), timestamp=\(finalTimestamp)", category: BlendLogger.oracle)
        debugLogger.info("🔮 ✅ PriceData created for \(symbol): $\(priceData.priceInUSD)")
        
        return priceData
    }
    
    /// Parse i128 to Decimal with proper fixed-point arithmetic
    /// Blend Protocol uses 7 decimal places for prices (10^7 = 10,000,000)
    private func parseI128ToDecimal(_ value: Int128PartsXDR) -> Decimal {
        BlendLogger.debug("🔮 🔢 Parsing i128 value: hi=\(value.hi), lo=\(value.lo)", category: BlendLogger.oracle)
        debugLogger.info("🔮 🔢 parseI128ToDecimal - hi: \(value.hi), lo: \(value.lo)")
        
        // Convert i128 to a single 128-bit integer value
        let fullValue: Decimal
        
        if value.hi == 0 {
            // Simple case: only low 64 bits are used
            fullValue = Decimal(value.lo)
            debugLogger.info("🔮 🔢 Simple case - using lo value: \(value.lo)")
        } else if value.hi == -1 && (value.lo & 0x8000000000000000) != 0 {
            // Negative number in two's complement
            let signedLo = Int64(bitPattern: value.lo)
            fullValue = Decimal(signedLo)
            debugLogger.info("🔮 🔢 Negative case - signed lo: \(signedLo)")
        } else {
            // Large positive number: combine hi and lo parts
            // hi represents the upper 64 bits, lo represents the lower 64 bits
            let hiDecimal = Decimal(value.hi) * Decimal(sign: .plus, exponent: 64, significand: 1)
            let loDecimal = Decimal(value.lo)
            fullValue = hiDecimal + loDecimal
            debugLogger.info("🔮 🔢 Large number case - combined value: \(fullValue)")
        }
        
        // The value from the oracle is in fixed-point format with 7 decimals
        // So we need to return the raw value as-is (it's already scaled)
        // The PriceData.priceInUSD property will handle the conversion to float
        
        BlendLogger.debug("🔮 💰 Parsed fixed-point price: \(fullValue)", category: BlendLogger.oracle)
        debugLogger.info("🔮 💰 Final parsed price (fixed-point): \(fullValue)")
        
        return fullValue
    }
    
    /// Helper method to get asset symbol from address
    private func getAssetSymbol(for address: String) -> String {
        print("asset address: \(address)")
        
        let assetMapping = [
            BlendUSDCConstants.Testnet.usdc: "USDC",
            BlendUSDCConstants.Testnet.xlm: "XLM",
            BlendUSDCConstants.Testnet.blnd: "BLND",
            BlendUSDCConstants.Testnet.weth: "wETH",
            BlendUSDCConstants.Testnet.wbtc: "wBTC"
        ]
        if !StellarContractID.isStrKeyContract(address) {
            let asset = decode(address: address) ?? ""
            return assetMapping[asset]!
        }
    
        return assetMapping[address] ?? address
    }
    
    private func decode(address: String) -> String? {
        try? StellarContractID.encode(hex: address)
    }
    
    private func withRetry<T>(
        maxAttempts: Int,
        delay: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        BlendLogger.debug("🔮 🔄 Starting retry mechanism (max: \(maxAttempts), delay: \(delay)s)", category: BlendLogger.oracle)
        debugLogger.info("🔮 🔄 withRetry called - maxAttempts: \(maxAttempts), delay: \(delay)s")
        
        for attempt in 1...maxAttempts {
            do {
                BlendLogger.debug("🔮 🎯 Attempt \(attempt)/\(maxAttempts)", category: BlendLogger.oracle)
                debugLogger.info("🔮 🎯 Starting attempt \(attempt) of \(maxAttempts)")
                
                let result = try await operation()
                
                if attempt > 1 {
                    BlendLogger.info("🔮 ✅ Operation succeeded on attempt \(attempt)", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ✅ Success after \(attempt) attempts")
                } else {
                    BlendLogger.debug("🔮 ✅ Operation succeeded on first attempt", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ✅ Success on first attempt")
                }
                
                return result
            } catch {
                lastError = error
                BlendLogger.warning("🔮 ❌ Attempt \(attempt) failed: \(error.localizedDescription)", category: BlendLogger.oracle)
                debugLogger.warning("🔮 ❌ Attempt \(attempt) failed with error: \(type(of: error))")
                debugLogger.warning("🔮 ❌ Error details: \(error.localizedDescription)")
                
                if attempt < maxAttempts {
                    BlendLogger.debug("🔮 ⏳ Retrying in \(delay) seconds...", category: BlendLogger.oracle)
                    debugLogger.info("🔮 ⏳ Waiting \(delay)s before retry \(attempt + 1)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    BlendLogger.error("🔮 💥 All \(maxAttempts) attempts failed", category: BlendLogger.oracle)
                    debugLogger.error("🔮 💥 Maximum retry attempts (\(maxAttempts)) exceeded")
                }
            }
        }
        
        BlendLogger.error("🔮 💥 Retry mechanism exhausted, throwing last error", category: BlendLogger.oracle)
        debugLogger.error("🔮 💥 Final error: \(lastError?.localizedDescription ?? "Unknown")")
        throw OracleError.maxRetriesExceeded(attempts: maxAttempts, lastError: lastError)
    }
}

// MARK: - Oracle Errors

public enum OracleError: LocalizedError, CustomDebugStringConvertible {
    case priceNotFound(asset: String, reason: String? = nil)
    case priceNotAvailable(asset: String, reason: String? = nil)
    case noDataAvailable(context: String? = nil)
    case maxRetriesExceeded(attempts: Int, lastError: Error? = nil)
    case invalidResponse(details: String? = nil, rawData: String? = nil)
    case networkError(Error, context: String? = nil)
    case contractError(code: String, message: String)
    case assetParameterError(asset: String, reason: String)
    case parsingError(field: String, expectedType: String, actualType: String)
    case simulationError(transactionHash: String?, error: String)
    case rpcError(endpoint: String, statusCode: Int?, message: String)
    
    public var errorDescription: String? {
        switch self {
        case .priceNotFound(let asset, let reason):
            let baseMessage = "Price not found for asset: \(asset)"
            return reason != nil ? "\(baseMessage). Reason: \(reason!)" : baseMessage
            
        case .priceNotAvailable(let asset, let reason):
            let baseMessage = "Price data not available for asset: \(asset)"
            return reason != nil ? "\(baseMessage). Reason: \(reason!)" : baseMessage
            
        case .noDataAvailable(let context):
            let baseMessage = "No oracle data available"
            return context != nil ? "\(baseMessage). Context: \(context!)" : baseMessage
            
        case .maxRetriesExceeded(let attempts, let lastError):
            let baseMessage = "Maximum retry attempts exceeded (\(attempts) attempts)"
            return lastError != nil ? "\(baseMessage). Last error: \(lastError!.localizedDescription)" : baseMessage
            
        case .invalidResponse(let details, _):
            let baseMessage = "Invalid response from oracle"
            return details != nil ? "\(baseMessage). Details: \(details!)" : baseMessage
            
        case .networkError(let error, let context):
            let baseMessage = "Network error: \(error.localizedDescription)"
            return context != nil ? "\(baseMessage). Context: \(context!)" : baseMessage
            
        case .contractError(let code, let message):
            return "Contract error [\(code)]: \(message)"
            
        case .assetParameterError(let asset, let reason):
            return "Failed to create asset parameter for \(asset): \(reason)"
            
        case .parsingError(let field, let expectedType, let actualType):
            return "Parsing error for field '\(field)': expected \(expectedType), got \(actualType)"
            
        case .simulationError(let transactionHash, let error):
            let baseMessage = "Transaction simulation failed: \(error)"
            return transactionHash != nil ? "\(baseMessage) (tx: \(transactionHash!))" : baseMessage
            
        case .rpcError(let endpoint, let statusCode, let message):
            let baseMessage = "RPC error from \(endpoint): \(message)"
            return statusCode != nil ? "\(baseMessage) (status: \(statusCode!))" : baseMessage
        }
    }
    
    public var debugDescription: String {
        switch self {
        case .priceNotFound(let asset, let reason):
            return "OracleError.priceNotFound(asset: \(asset), reason: \(reason ?? "nil"))"
            
        case .priceNotAvailable(let asset, let reason):
            return "OracleError.priceNotAvailable(asset: \(asset), reason: \(reason ?? "nil"))"
            
        case .noDataAvailable(let context):
            return "OracleError.noDataAvailable(context: \(context ?? "nil"))"
            
        case .maxRetriesExceeded(let attempts, let lastError):
            return "OracleError.maxRetriesExceeded(attempts: \(attempts), lastError: \(lastError?.localizedDescription ?? "nil"))"
            
        case .invalidResponse(let details, let rawData):
            return "OracleError.invalidResponse(details: \(details ?? "nil"), rawData: \(rawData ?? "nil"))"
            
        case .networkError(let error, let context):
            return "OracleError.networkError(\(error), context: \(context ?? "nil"))"
            
        case .contractError(let code, let message):
            return "OracleError.contractError(code: \(code), message: \(message))"
            
        case .assetParameterError(let asset, let reason):
            return "OracleError.assetParameterError(asset: \(asset), reason: \(reason))"
            
        case .parsingError(let field, let expectedType, let actualType):
            return "OracleError.parsingError(field: \(field), expectedType: \(expectedType), actualType: \(actualType))"
            
        case .simulationError(let transactionHash, let error):
            return "OracleError.simulationError(transactionHash: \(transactionHash ?? "nil"), error: \(error))"
            
        case .rpcError(let endpoint, let statusCode, let message):
            return "OracleError.rpcError(endpoint: \(endpoint), statusCode: \(statusCode?.description ?? "nil"), message: \(message))"
        }
    }
    
    /// Get the underlying error if this is a wrapper error
    public var underlyingError: Error? {
        switch self {
        case .networkError(let error, _):
            return error
        case .maxRetriesExceeded(_, let lastError):
            return lastError
        default:
            return nil
        }
    }
    
    /// Check if this error is recoverable (can be retried)
    public var isRecoverable: Bool {
        switch self {
        case .networkError, .rpcError, .simulationError:
            return true
        case .maxRetriesExceeded, .contractError, .assetParameterError, .parsingError:
            return false
        case .invalidResponse, .priceNotFound, .priceNotAvailable, .noDataAvailable:
            return false
        }
    }
    
    /// Get error severity level
    public var severity: ErrorSeverity {
        switch self {
        case .priceNotFound, .priceNotAvailable:
            return .warning
        case .noDataAvailable:
            return .warning
        case .networkError, .rpcError:
            return .error
        case .maxRetriesExceeded, .contractError, .simulationError:
            return .critical
        case .invalidResponse, .assetParameterError, .parsingError:
            return .error
        }
    }
}

/// Error severity levels for better error categorization
public enum ErrorSeverity: String, CaseIterable {
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    public var emoji: String {
        switch self {
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "💥"
        }
    }
}
// MARK: - Performance Measurement Extension

extension BlendOracleService {
    /// Measure performance of an async operation
    private func measurePerformance<T>(
        operation: String,
        category: OSLog,
        work: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await work()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        BlendLogger.debug("⏱️ \(operation) completed in \(String(format: "%.3f", timeElapsed))s", category: category)
        return result
    }
    
    /// Enhanced error logging with severity and context
    private func logError(_ error: Error, context: String, asset: String? = nil) {
        let symbol = asset != nil ? getAssetSymbol(for: asset!) : nil
        let assetInfo = symbol != nil ? " [\(symbol!)]" : ""
        
        if let oracleError = error as? OracleError {
            let severity = oracleError.severity
            let emoji = severity.emoji
            
            BlendLogger.error("\(emoji) Oracle Error\(assetInfo): \(oracleError.localizedDescription)", 
                            category: BlendLogger.oracle)
            debugLogger.error("\(emoji) \(severity.rawValue): \(oracleError.debugDescription)")
            debugLogger.error("🔍 Context: \(context)")
            
            // Log underlying error if present
            if let underlyingError = oracleError.underlyingError {
                debugLogger.error("🔗 Underlying error: \(underlyingError.localizedDescription)")
            }
            
            // Log recovery suggestion
            if oracleError.isRecoverable {
                debugLogger.info("🔄 Error is recoverable - retry may succeed")
            } else {
                debugLogger.warning("⚠️ Error is not recoverable - manual intervention may be required")
            }
        } else {
            BlendLogger.error("❌ Unexpected Error\(assetInfo): \(error.localizedDescription)", 
                            category: BlendLogger.oracle)
            debugLogger.error("❌ Unexpected error type: \(type(of: error))")
            debugLogger.error("🔍 Context: \(context)")
        }
    }
    
    /// Log successful operations with metrics
    private func logSuccess(operation: String, asset: String? = nil, duration: TimeInterval? = nil, additionalInfo: [String: Any] = [:]) {
        let symbol = asset != nil ? getAssetSymbol(for: asset!) : nil
        let assetInfo = symbol != nil ? " [\(symbol!)]" : ""
        let durationInfo = duration != nil ? " in \(String(format: "%.3f", duration!))s" : ""
        
        BlendLogger.info("✅ \(operation)\(assetInfo) completed successfully\(durationInfo)", category: BlendLogger.oracle)
        
        if !additionalInfo.isEmpty {
            for (key, value) in additionalInfo {
                debugLogger.info("📊 \(key): \(value)")
            }
        }
    }
    
    /// Log operation start with context
    private func logOperationStart(operation: String, asset: String? = nil, parameters: [String: Any] = [:]) {
        let symbol = asset != nil ? getAssetSymbol(for: asset!) : nil
        let assetInfo = symbol != nil ? " [\(symbol!)]" : ""
        
        BlendLogger.debug("🚀 Starting \(operation)\(assetInfo)", category: BlendLogger.oracle)
        
        if !parameters.isEmpty {
            debugLogger.info("📋 Parameters:")
            for (key, value) in parameters {
                debugLogger.info("  - \(key): \(value)")
            }
        }
    }
} 
