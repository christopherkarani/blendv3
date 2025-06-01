import Foundation
import stellarsdk

// MARK: - Response Parsing Extensions

extension BackstopContractService {
    
    // MARK: - Basic Type Parsing
    
    /// Parse i128 response from contract
    internal func parseI128Response(_ response: SCValXDR) throws -> Int128 {
        guard case .i128(let value) = response else {
            throw BackstopError.parsingError(
                "parseI128Response",
                expectedType: "i128",
                actualType: String(describing: type(of: response))
            )
        }
        
        return convertI128PartsToInt128(value)
    }
    
    /// Parse address response from contract
    internal func parseAddressResponse(_ response: SCValXDR) throws -> String {
        guard case .address(let addressXDR) = response else {
            throw BackstopError.parsingError(
                "parseAddressResponse",
                expectedType: "address",
                actualType: String(describing: type(of: response))
            )
        }
        
        return try extractAddressString(from: addressXDR)
    }
    
    /// Parse Q4W struct response
    internal func parseQ4WResponse(_ response: SCValXDR) throws -> Q4W {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BackstopError.parsingError(
                "parseQ4WResponse",
                expectedType: "map",
                actualType: String(describing: type(of: response))
            )
        }
        
        var amount: Int128?
        var exp: UInt64?
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "amount":
                guard case .i128(let amountValue) = pair.val else {
                    throw BackstopError.parsingError("Q4W.amount", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                amount = convertI128PartsToInt128(amountValue)
                
            case "exp":
                guard case .u64(let expValue) = pair.val else {
                    throw BackstopError.parsingError("Q4W.exp", expectedType: "u64", actualType: String(describing: type(of: pair.val)))
                }
                exp = expValue
                
            default:
                continue
            }
        }
        
        guard let validAmount = amount, let validExp = exp else {
            throw BackstopError.parsingError("Q4W", expectedType: "complete struct", actualType: "incomplete")
        }
        
        return Q4W(amount: validAmount, exp: validExp)
    }
    
    // MARK: - Complex Struct Parsing
    
    /// Parse UserBalance struct response
    internal func parseUserBalanceResponse(_ response: SCValXDR) throws -> UserBalance {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BackstopError.parsingError(
                "parseUserBalanceResponse",
                expectedType: "map",
                actualType: String(describing: type(of: response))
            )
        }
        
        var q4wArray: [Q4W] = []
        var shares: Int128?
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "q4w":
                guard case .vec(let vecOptional) = pair.val,
                      let vec = vecOptional else {
                    throw BackstopError.parsingError("UserBalance.q4w", expectedType: "vec", actualType: String(describing: type(of: pair.val)))
                }
                
                for item in vec {
                    let q4w = try parseQ4WResponse(item)
                    q4wArray.append(q4w)
                }
                
            case "shares":
                guard case .i128(let sharesValue) = pair.val else {
                    throw BackstopError.parsingError("UserBalance.shares", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                shares = convertI128PartsToInt128(sharesValue)
                
            default:
                continue
            }
        }
        
        guard let validShares = shares else {
            throw BackstopError.parsingError("UserBalance", expectedType: "complete struct", actualType: "missing shares")
        }
        
        return UserBalance(q4w: q4wArray, shares: validShares)
    }
    
    /// Parse PoolBackstopData struct response
    internal func parsePoolBackstopDataResponse(_ response: SCValXDR) throws -> PoolBackstopData {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BackstopError.parsingError(
                "parsePoolBackstopDataResponse",
                expectedType: "map",
                actualType: String(describing: type(of: response))
            )
        }
        
        var blnd: Int128?
        var q4wPct: Int128?
        var shares: Int128?
        var tokenSpotPrice: Int128?
        var tokens: Int128?
        var usdc: Int128?
        
        debugLogger.debug("🛡️ 🔍 Parsing PoolBackstopData from \(map.count) map entries")
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "blnd":
                guard case .i128(let blndValue) = pair.val else {
                    throw BackstopError.parsingError("PoolBackstopData.blnd", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                blnd = convertI128PartsToInt128(blndValue)
                debugLogger.debug("🛡️ 📊 Parsed blnd: \(blnd!)")
                
            case "q4w_pct":
                guard case .i128(let q4wValue) = pair.val else {
                    throw BackstopError.parsingError("PoolBackstopData.q4w_pct", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                q4wPct = convertI128PartsToInt128(q4wValue)
                debugLogger.debug("🛡️ 📊 Parsed q4w_pct: \(q4wPct!)")
                
            case "shares":
                guard case .i128(let sharesValue) = pair.val else {
                    throw BackstopError.parsingError("PoolBackstopData.shares", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                shares = convertI128PartsToInt128(sharesValue)
                debugLogger.debug("🛡️ 📊 Parsed shares: \(shares!)")
                
            case "token_spot_price":
                guard case .i128(let spotPriceValue) = pair.val else {
                    throw BackstopError.parsingError("PoolBackstopData.token_spot_price", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                tokenSpotPrice = convertI128PartsToInt128(spotPriceValue)
                debugLogger.debug("🛡️ 📊 Parsed token_spot_price: \(tokenSpotPrice!)")
                
            case "tokens":
                guard case .i128(let tokensValue) = pair.val else {
                    throw BackstopError.parsingError("PoolBackstopData.tokens", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                tokens = convertI128PartsToInt128(tokensValue)
                debugLogger.debug("🛡️ 📊 Parsed tokens: \(tokens!)")
                
            case "usdc":
                guard case .i128(let usdcValue) = pair.val else {
                    throw BackstopError.parsingError("PoolBackstopData.usdc", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                usdc = convertI128PartsToInt128(usdcValue)
                debugLogger.debug("🛡️ 📊 Parsed usdc: \(usdc!)")
                
            default:
                debugLogger.debug("🛡️ ⚠️ Unknown field in PoolBackstopData: \(key)")
                continue
            }
        }
        
        // All fields are optional in the response, use 0 as default for missing values
        let result = PoolBackstopData(
            blnd: blnd ?? 0,
            q4wPercent: q4wPct ?? 0,
            shares: shares ?? 0,
            tokenSpotPrice: tokenSpotPrice ?? 0,
            tokens: tokens ?? 0,
            usdc: usdc ?? 0
        )
        
        debugLogger.debug("🛡️ ✅ Final PoolBackstopData: blnd=\(result.blnd), q4w=\(result.q4wPercent), tokens=\(result.tokens), usdc=\(result.usdc)")
        
        return result
    }
    
    // MARK: - Helper Functions
    
    /// Convert i128 parts to Int128
    private func convertI128PartsToInt128(_ parts: Int128PartsXDR) -> Int128 {
        if parts.hi == 0 {
            return Int128(parts.lo)
        } else if parts.hi == -1 && (parts.lo & 0x8000000000000000) != 0 {
            let signedLo = Int64(bitPattern: parts.lo)
            return Int128(signedLo)
        } else {
            // Large number: combine hi and lo parts
            let hiValue = Int128(parts.hi) << 64
            let loValue = Int128(parts.lo)
            return hiValue + loValue
        }
    }
    
    /// Extract address string from SCAddressXDR
    private func extractAddressString(from addressXDR: SCAddressXDR) throws -> String {
        switch addressXDR {
        case .account(let accountXDR):
            return accountXDR.accountId
        case .contract(let contractXDR):
            return try StellarContractID.encode(hex: contractXDR.wrapped.hexEncodedString())
        }
    }
}

// MARK: - Emission Data Parsing

extension BackstopContractService {
    
    /// Parse BackstopEmissionsData struct response
    internal func parseBackstopEmissionsDataResponse(_ response: SCValXDR) throws -> BackstopEmissionsData {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BackstopError.parsingError(
                "parseBackstopEmissionsDataResponse",
                expectedType: "map",
                actualType: String(describing: type(of: response))
            )
        }
        
        var index: Int128?
        var lastTime: UInt64?
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "index":
                guard case .i128(let indexValue) = pair.val else {
                    throw BackstopError.parsingError("BackstopEmissionsData.index", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                index = convertI128PartsToInt128(indexValue)
                
            case "last_time":
                guard case .u64(let timeValue) = pair.val else {
                    throw BackstopError.parsingError("BackstopEmissionsData.last_time", expectedType: "u64", actualType: String(describing: type(of: pair.val)))
                }
                lastTime = timeValue
                
            default:
                continue
            }
        }
        
        guard let validIndex = index, let validLastTime = lastTime else {
            throw BackstopError.parsingError("BackstopEmissionsData", expectedType: "complete struct", actualType: "incomplete")
        }
        
        return BackstopEmissionsData(index: validIndex, lastTime: validLastTime)
    }
    
    /// Parse UserEmissionData struct response
    internal func parseUserEmissionDataResponse(_ response: SCValXDR) throws -> UserEmissionData {
        guard case .map(let mapOptional) = response,
              let map = mapOptional else {
            throw BackstopError.parsingError(
                "parseUserEmissionDataResponse",
                expectedType: "map",
                actualType: String(describing: type(of: response))
            )
        }
        
        var accrued: Int128?
        var index: Int128?
        
        for pair in map {
            guard case .symbol(let key) = pair.key else { continue }
            
            switch key {
            case "accrued":
                guard case .i128(let accruedValue) = pair.val else {
                    throw BackstopError.parsingError("UserEmissionData.accrued", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                accrued = convertI128PartsToInt128(accruedValue)
                
            case "index":
                guard case .i128(let indexValue) = pair.val else {
                    throw BackstopError.parsingError("UserEmissionData.index", expectedType: "i128", actualType: String(describing: type(of: pair.val)))
                }
                index = convertI128PartsToInt128(indexValue)
                
            default:
                continue
            }
        }
        
        guard let validAccrued = accrued, let validIndex = index else {
            throw BackstopError.parsingError("UserEmissionData", expectedType: "complete struct", actualType: "incomplete")
        }
        
        return UserEmissionData(accrued: validAccrued, index: validIndex)
    }
}
