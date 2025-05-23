//
//  DepositResponse.swift
//  stellarsdk
//
//  Created by Razvan Chelemen on 07/09/2018.
//  Copyright © 2018 Soneso. All rights reserved.
//

import Foundation

public struct DepositResponse: Decodable {

    /// (Deprecated, use instructions instead) Terse but complete instructions for how to deposit the asset. In the case of most cryptocurrencies it is just an address to which the deposit should be sent.
    public var how:String
    
    /// (optional) JSON object containing the SEP-9 financial account fields that describe how to complete the off-chain deposit.
    /// If the anchor cannot provide this information in the response, the wallet should query the /transaction endpoint to get this asynchonously.
    public var instructions:[String:DepositInstruction]?
    
    /// (optional) The anchor's ID for this deposit. The wallet will use this ID to query the /transaction endpoint to check status of the request.
    public var id:String?
    
    /// (optional) Estimate of how long the deposit will take to credit in seconds.
    public var eta:Int?
    
    /// (optional) Minimum amount of an asset that a user can deposit.
    public var minAmount:Double?
    
    /// (optional) Maximum amount of asset that a user can deposit.
    public var maxAmount:Double?
    
    /// (optional) Fixed fee (if any). In units of the deposited asset.
    public var feeFixed:Double?
    
    /// (optional) Percentage fee (if any). In units of percentage points.
    public var feePercent:Double?
    
    /// (optional) Any additional data needed as an input for this deposit, example: Bank Name
    public var extraInfo:ExtraInfo?
        
    /// Properties to encode and decode
    private enum CodingKeys: String, CodingKey {
        case how = "how"
        case id = "id"
        case eta = "eta"
        case minAmount = "min_amount"
        case maxAmount = "max_amount"
        case feeFixed = "fee_fixed"
        case feePercent = "fee_percent"
        case extraInfo = "extra_info"
        case instructions
    }
    
    /**
     Initializer - creates a new instance by decoding from the given decoder.
     
     - Parameter decoder: The decoder containing the data
     */
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        how = try values.decode(String.self, forKey: .how)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        eta = try values.decodeIfPresent(Int.self, forKey: .eta)
        minAmount = try values.decodeIfPresent(Double.self, forKey: .minAmount)
        maxAmount = try values.decodeIfPresent(Double.self, forKey: .maxAmount)
        feeFixed = try values.decodeIfPresent(Double.self, forKey: .feeFixed)
        feePercent = try values.decodeIfPresent(Double.self, forKey: .feePercent)
        extraInfo = try values.decodeIfPresent(ExtraInfo.self, forKey: .extraInfo)
        instructions = try values.decodeIfPresent([String:DepositInstruction].self, forKey: .instructions)
    }
    
}

public struct DepositInstruction: Decodable {

    /// The value of the field.
    public var value:String
    
    /// A human-readable description of the field. This can be used by an anchor
    /// to provide any additional information about fields that are not defined
    /// in the SEP-9 standard.
    public var description:String
    

    /// Properties to encode and decode
    private enum CodingKeys: String, CodingKey {
        case value
        case description
    }
    
    /**
     Initializer - creates a new instance by decoding from the given decoder.
     
     - Parameter decoder: The decoder containing the data
     */
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        value = try values.decode(String.self, forKey: .value)
        description = try values.decode(String.self, forKey: .description)
    }
}


public struct ExtraInfo: Decodable {

    /// (optional) Additional details about the deposit process.
    public var message:String?
    

    /// Properties to encode and decode
    private enum CodingKeys: String, CodingKey {
        case message
    }
    
    /**
     Initializer - creates a new instance by decoding from the given decoder.
     
     - Parameter decoder: The decoder containing the data
     */
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        message = try values.decodeIfPresent(String.self, forKey: .message)
    }
}
