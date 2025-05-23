//
//  WithdrawResponse.swift
//  stellarsdk
//
//  Created by Razvan Chelemen on 07/09/2018.
//  Copyright © 2018 Soneso. All rights reserved.
//

import Foundation

public struct WithdrawResponse: Decodable {

    /// (optional) The account the user should send its token back to. This field can be omitted if the anchor cannot provide this information at the time of the request.
    public var accountId:String?
    
    /// (optional) type of memo to attach to transaction, one of text, id or hash
    public var memoType:String?
    
    /// (optional) Value of memo to attach to transaction, for hash this should be base64-encoded. The anchor should use this memo to match the Stellar transaction with the database entry associated created to represent it.
    public var memo:String?
    
    /// (optional) The anchor's ID for this withdrawal. The wallet will use this ID to query the /transaction endpoint to check status of the request.
    public var id:String?
    
    /// (optional) Estimate of how long the withdrawal will take to credit in seconds.
    public var eta:Int?
    
    /// (optional) Minimum amount of an asset that a user can withdraw.
    public var minAmount:Double?
    
    /// (optional) Maximum amount of asset that a user can withdraw.
    public var maxAmount:Double?
    
    /// (optional) If there is a fee for withdraw. In units of the withdrawn asset.
    public var feeFixed:Double?
    
    /// (optional) If there is a percent fee for withdraw.
    public var feePercent:Double?
    
    /// (optional) Any additional data needed as an input for this withdraw, example: Bank Name.
    public var extraInfo:ExtraInfo?
    
    /// Properties to encode and decode
    private enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case memoType = "memo_type"
        case memo = "memo"
        case id = "id"
        case eta = "eta"
        case minAmount = "min_amount"
        case maxAmount = "max_amount"
        case feeFixed = "fee_fixed"
        case feePercent = "fee_percent"
        case extraInfo = "extra_info"
    }
    
    /**
     Initializer - creates a new instance by decoding from the given decoder.
     
     - Parameter decoder: The decoder containing the data
     */
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try values.decodeIfPresent(String.self, forKey: .accountId)
        memoType = try values.decodeIfPresent(String.self, forKey: .memoType)
        memo = try values.decodeIfPresent(String.self, forKey: .memo)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        eta = try values.decodeIfPresent(Int.self, forKey: .eta)
        minAmount = try values.decodeIfPresent(Double.self, forKey: .minAmount)
        maxAmount = try values.decodeIfPresent(Double.self, forKey: .maxAmount)
        feeFixed = try values.decodeIfPresent(Double.self, forKey: .feeFixed)
        feePercent = try values.decodeIfPresent(Double.self, forKey: .feePercent)
        extraInfo = try values.decodeIfPresent(ExtraInfo.self, forKey: .extraInfo)
    }
    
}
