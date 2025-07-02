//
//  BlendConstants.swift
//  Blendv3
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
@preconcurrency import stellarsdk
import os.log

/// Constants and utilities for interacting with the Blend Protocol
/// Updated with latest contract addresses from blend-utils
/// Testnet source: https://github.com/blend-capital/blend-utils/blob/main/testnet.contracts.json
/// Mainnet source: https://github.com/blend-capital/blend-utils/blob/main/mainnet.contracts.json
public struct BlendConstants {
    
    static let assets = ["USDC", "XLM", "wETH", "wBTC"]
    
    // MARK: - Logging
    
    /// Logger for contract address usage
    private static let logger = Logger(subsystem: "com.blendv3.constants", category: "BlendConstants")
    
    // MARK: - Network Configuration
    
    /// Network type for determining which contract addresses to use
    public enum NetworkType: Sendable {
        case testnet
        case mainnet
        
        /// Human-readable description of the network
        public var description: String {
            switch self {
            case .testnet:
                return "Testnet"
            case .mainnet:
                return "Mainnet"
            }
        }
        
        /// Corresponding Stellar network enum
        public var stellarNetwork: stellarsdk.Network {
            switch self {
            case .testnet:
                return .testnet
            case .mainnet:
                return .public
            }
        }
    }
    
    // MARK: - Mainnet Contract Addresses
    
    public struct Mainnet {
        /// Bootstrapper contract address on mainnet
        public static let bootstrapper = "CBUTN4KJSULJAUZYTYIGSMYAOO7PBJSAQ5OP6UTGYHOXA6UQYBAEOBB3"
        
        /// Emitter contract address on mainnet
        public static let emitter = "CCOQM6S7ICIUWA225O5PSJWUBEMXGFSSW2PQFO6FP4DQEKMS5DASRGRR"
        
        /// Pool Factory contract address on mainnet
        public static let poolFactory = "CCZD6ESMOGMPWH2KRO4O7RGTAPGTUPFWFQBELQSS7ZUK63V3TZWETGAG"
        
        /// Backstop contract address on mainnet
        public static let backstop = "CAO3AGAMZVRMHITL36EJ2VZQWKYRPWMQAPDQD5YEOF3GIF7T44U4JAL3"
        
        /// BLND token contract address on mainnet
        public static let blnd = "CD25MNVTZDL4Y3XBCPCJXGXATV5WUHHOWMYFF4YBEGU5FCPGMYTVG5JY"
        
        /// USDC asset contract address on mainnet
        public static let usdc = "CCW67TSZV3SSS2HXMBQ5JFGCKJNXKZM7UQUWUZPUTHXSTZLEO7SJMI75"
        
        /// XLM asset contract address on mainnet
        public static let xlm = "CAS3J7GYLGXMF6TDJBBYYSE3HQ6BBSMLNUQ34T6TZMYMW2EVH34XOWMA"
        
        /// Comet Factory contract address on mainnet
        public static let cometFactory = "CA2LVIPU6HJHHPPD6EDDYJTV2QEUBPGOAVJ4VIYNTMFUCRM4LFK3TJKF"
        
        /// Comet (BLND:USDC liquidity pool) contract address on mainnet
        public static let comet = "CAS3FL6TLZKDGGSISDBWGGPXT3NRR4DYTZD7YOD3HMYO6LTJUVGRVEAM"
        
        /// Fixed XLM-USDC Pool contract address on mainnet
        public static let fixedXlmUsdcPool = "CDVQVKOY2YSXS2IC7KN6MNASSHPAO7UN2UR2ON4OI2SKMFJNVAMDX6DP"
        
        /// YieldBlox Pool contract address on mainnet
        public static let yieldBloxPool = "CBP7NO6F7FRDHSOFQBT2L2UWYIZ2PU76JKVRYAQTG3KZSQLYAOKIF2WB"
        
        /// Oracle contract address on mainnet (using fixed XLM-USDC pool as oracle source)
        public static let oracle = fixedXlmUsdcPool
        
        /// Log all mainnet contract addresses
        public static func logAddresses() {
            logger.info("🌐 Using MAINNET contract addresses:")
            logger.info("  📋 Pool Factory: \(poolFactory)")
            logger.info("  🏊 Primary Pool (Fixed XLM-USDC): \(fixedXlmUsdcPool)")
            logger.info("  💰 USDC: \(usdc)")
            logger.info("  🪙 BLND: \(blnd)")
            logger.info("  🛡️ Backstop: \(backstop)")
            logger.info("  📡 Emitter: \(emitter)")
            logger.info("  ☄️ Comet (BLND:USDC LP): \(comet)")
            logger.info("  🏭 Comet Factory: \(cometFactory)")
            logger.info("  🌟 XLM: \(xlm)")
            logger.info("  🚀 Bootstrapper: \(bootstrapper)")
            logger.info("  📈 YieldBlox Pool: \(yieldBloxPool)")
        }
    }
    
    // MARK: - Testnet Contract Addresses
    
    public struct Testnet {
        /// Pool Factory contract address on testnet (Updated)
        public static let poolFactory = "CDIE73IJJKOWXWCPU5GWQ745FUKWCSH3YKZRF5IQW7GE3G7YAZ773MYK"
        
        /// Primary Pool contract address on testnet (TestnetV2)
        public static let xlmUsdcPool = "CCLBPEYS3XFK65MYYXSBMOGKUI4ODN5S7SUZBGD7NALUQF64QILLX5B5"
        
        /// XLM asset contract address on testnet
        public static let xlm = "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC"
        
        /// USDC asset contract address on testnet
        public static let usdc = "CAQCFVLOBK5GIULPNZRGATJJMIZL5BSP7X5YJVMGCPTUEPFM4AVSRCJU"
        
        /// BLND token contract address on testnet
        public static let blnd = "CB22KRA3YZVCNCQI64JQ5WE7UY2VAV7WFLK6A2JN3HEX56T2EDAFO7QF"
        
        /// wETH token contract address on testnet
        public static let weth = "CAZAQB3D7KSLSNOSQKYD2V4JP5V2Y3B4RDJZRLBFCCIXDCTE3WHSY3UE"
        
        /// wBTC token contract address on testnet
        public static let wbtc = "CAP5AMC2OHNVREO66DFIN6DHJMPOBAJ2KCDDIMFBR7WWJH5RZBFM3UEI"
        
        /// Backstop contract address on testnet (Updated)
        public static let backstop = "CC4TSDVQKBAYMK4BEDM65CSNB3ISI2A54OOBRO6IPSTFHJY3DEEKHRKV"
        
        /// Emitter contract address on testnet (Updated)
        public static let emitter = "CA3WEGSM5ILLQKPJJUJJFZF6VG3K6NCQAOBQKF4WWWMRT4HWLQZYOVUD"
        
        /// Comet (BLND:USDC liquidity pool) contract address on testnet (Updated)
        public static let comet = "CAVWKK4WB7SWLKI7VBPPGP6KNUKLUAWQIHE44V7G7MYOG4K23PW2PXKJ"
        
        /// Oracle contract address on testnet (Updated)
        public static let oracle = "CCYHURAC5VTN2ZU663UUS5F24S4GURDPO4FHZ75JLN5DMLRTLCG44H44"
        
        /// Comet factory contract address on testnet (Updated)
        public static let cometFactory = "CD7E4SS4ZIY2JDEZP3PTWAIBBWMRG2NNFFXKHC7FCW43ZWTSI2KJYG5P"
        
        public static let assetContracts = [usdc, xlm, wbtc, weth, blnd]
        
        /// Log all testnet contract addresses
        public static func logAddresses() {
            logger.info("🧪 Using TESTNET contract addresses:")
            logger.info("  📋 Pool Factory: \(poolFactory)")
            logger.info("  🏊 Primary Pool (TestnetV2): \(xlmUsdcPool)")
            logger.info("  🌟 XLM: \(xlm)")
            logger.info("  💰 USDC: \(usdc)")
            logger.info("  🪙 BLND: \(blnd)")
            logger.info("  🛡️ Backstop: \(backstop)")
            logger.info("  📡 Emitter: \(emitter)")
            logger.info("  ☄️ Comet (BLND:USDC LP): \(comet)")
            logger.info("  🏭 Comet Factory: \(cometFactory)")
            logger.info("  🔮 Oracle: \(oracle)")
            logger.info("  💎 wETH: \(weth)")
            logger.info("  ₿ wBTC: \(wbtc)")
        }
    }
    
    // MARK: - Dynamic Address Getters
    
    /// Get the appropriate contract addresses based on network type
    /// - Parameter network: The network type (testnet or mainnet)
    /// - Returns: The appropriate contract addresses for the network
    public static func addresses(for network: NetworkType) -> ContractAddresses {
        logger.info("🔄 Resolving contract addresses for \(network.description)")
        
        let addresses: ContractAddresses
        switch network {
        case .testnet:
            Testnet.logAddresses()
            addresses = ContractAddresses(
                poolFactory: Testnet.poolFactory,
                primaryPool: Testnet.xlmUsdcPool,
                usdc: Testnet.usdc,
                blnd: Testnet.blnd,
                backstop: Testnet.backstop,
                emitter: Testnet.emitter,
                comet: Testnet.comet,
                cometFactory: Testnet.cometFactory
            )
        case .mainnet:
            Mainnet.logAddresses()
            addresses = ContractAddresses(
                poolFactory: Mainnet.poolFactory,
                primaryPool: Mainnet.fixedXlmUsdcPool,
                usdc: Mainnet.usdc,
                blnd: Mainnet.blnd,
                backstop: Mainnet.backstop,
                emitter: Mainnet.emitter,
                comet: Mainnet.comet,
                cometFactory: Mainnet.cometFactory
            )
        }
        
        logger.info("✅ Contract addresses resolved for \(network.description)")
        return addresses
    }
    
    /// Container for contract addresses
    public struct ContractAddresses {
        public let poolFactory: String
        public let primaryPool: String
        public let usdc: String
        public let blnd: String
        public let backstop: String
        public let emitter: String
        public let comet: String
        public let cometFactory: String
        
        /// Log the contract addresses being used
        public func logUsage(for network: NetworkType) {
            logger.info("📊 Active contract addresses for \(network.description):")
            logger.info("  🏭 Pool Factory: \(poolFactory)")
            logger.info("  🏊 Primary Pool: \(primaryPool)")
            logger.info("  💰 USDC: \(usdc)")
            logger.info("  🪙 BLND: \(blnd)")
            logger.info("  🛡️ Backstop: \(backstop)")
            logger.info("  📡 Emitter: \(emitter)")
            logger.info("  ☄️ Comet: \(comet)")
            logger.info("  🏭 Comet Factory: \(cometFactory)")
        }
    }
    
    // MARK: - RPC Endpoints
    
    public struct RPC {
        public static let testnet = "https://soroban-testnet.stellar.org"
        public static let mainnet = "https://soroban-rpc.stellar.org"
        
        /// Get RPC URL for network type
        /// - Parameter network: The network type
        /// - Returns: The appropriate RPC URL
        public static func url(for network: NetworkType) -> String {
            let url: String
            switch network {
            case .testnet:
                url = testnet
            case .mainnet:
                url = mainnet
            }
            
            logger.info("🌐 Using RPC endpoint for \(network.description): \(url)")
            return url
        }
    }
    
    // MARK: - Function Names
    
    public struct Functions {
        public static let submit = "submit"
        public static let getReserve = "get_reserve"
    }
    
    // MARK: - Request Types
    
    /// Request types for the Blend pool submit function
    public enum RequestType: UInt32 {
        case supplyCollateral = 0
        case withdrawCollateral = 1
        case supply = 2
        case withdraw = 3
        case borrow = 4
        case repay = 5
        
        /// Human-readable description of the request type
        public var description: String {
            switch self {
            case .supplyCollateral:
                return "Supply Collateral"
            case .withdrawCollateral:
                return "Withdraw Collateral"
            case .supply:
                return "Supply"
            case .withdraw:
                return "Withdraw"
            case .borrow:
                return "Borrow"
            case .repay:
                return "Repay"
            }
        }
    }
    
    // MARK: - Scaling Constants
    
    /// USDC has 7 decimal places in Stellar
    private static let usdcDecimals: Int = 7
    private static let scalingFactor = Foundation.pow(Decimal(10), usdcDecimals)
    
    // MARK: - Utility Functions
    
    /// Scale a decimal amount to the contract's expected format
    /// - Parameter amount: The amount in standard USDC units (e.g., 100.50)
    /// - Returns: Scaled amount as Int128PartsXDR for contract calls
    public static func scaleAmount(_ amount: Decimal) -> Int128PartsXDR {
        let scaledValue = amount * scalingFactor
        let intValue = UInt64(truncating: scaledValue as NSNumber)
        
        logger.debug("💱 Scaling amount: \(amount) → \(intValue) (scaled by 10^\(usdcDecimals))")
        
        return Int128PartsXDR(hi: 0, lo: intValue)
    }
    
    /// Unscale an amount from contract format to standard decimal
    /// - Parameter scaledAmount: The scaled amount from contract response
    /// - Returns: Amount in standard USDC units
    public static func unscaleAmount(_ scaledAmount: Int128PartsXDR) -> Decimal {
        // Handle the Int128 parts - for most values, hi will be 0
        let value: UInt64
        if scaledAmount.hi == 0 {
            value = scaledAmount.lo
        } else {
            // For very large numbers, we'd need to handle the hi part
            // For now, assume most values fit in the lo part
            value = scaledAmount.lo
            logger.warning("⚠️ Large amount detected with hi=\(scaledAmount.hi), using only lo part")
        }
        
        let result = Decimal(value) / scalingFactor
        logger.debug("💱 Unscaling amount: \(value) → \(result) (unscaled by 10^\(usdcDecimals))")
        
        return result
    }
    
    /// Convert a regular decimal to a scaled decimal for calculations
    /// - Parameter amount: The amount to scale
    /// - Returns: Scaled decimal value
    public static func scaleDecimal(_ amount: Decimal) -> Decimal {
        return amount * scalingFactor
    }
    
    /// Convert a scaled decimal back to regular units
    /// - Parameter scaledAmount: The scaled amount
    /// - Returns: Unscaled decimal value
    public static func unscaleDecimal(_ scaledAmount: Decimal) -> Decimal {
        return scaledAmount / scalingFactor
    }
} 
