//
//  DataForAccountLocalTestCase.swift
//  stellarsdkTests
//
//  Created by Rogobete Christian on 19.02.18.
//  Copyright © 2018 Soneso. All rights reserved.
//

import XCTest
import stellarsdk

class DataForAccountLocalTestCase: XCTestCase {
    let sdk = StellarSDK()
    var dataForAccountResponsesMock: DataForAccountResponsesMock? = nil
    var mockRegistered = false
    let testSuccessAccountId = "GBZ3VAAP2T2WMKF6226FTC6OSQN6KKGAGPVCCCMDDVLCHYQMXTMNHLB3"
    
    override func setUp() {
        super.setUp()
        
        if !mockRegistered {
            URLProtocol.registerClass(ServerMock.self)
            mockRegistered = true
        }
        
        dataForAccountResponsesMock = DataForAccountResponsesMock()
        let sonesoValue = """
                    {
                        "value": "aXMgZnVu"
                    }
                    """
        dataForAccountResponsesMock?.addDataEntry(accountId:testSuccessAccountId, key:"soneso", value: sonesoValue)
        
    }
    
    override func tearDown() {
        dataForAccountResponsesMock = nil
        super.tearDown()
    }
    
    func testAccountNotFound() async {
        let responseEnum = await sdk.accounts.getDataForAccount(accountId: "AAAAA", key: "soneso")
        switch responseEnum {
        case .success(_):
            XCTFail()
        case .failure(let error):
            switch error {
            case .notFound( _, _):
                return
            default:
                XCTFail()
            }
        }
    }
    
    func testKeyNotFound() async {
        let responseEnum = await sdk.accounts.getDataForAccount(accountId: testSuccessAccountId, key: "stellar")
        switch responseEnum {
        case .success(_):
            XCTFail()
        case .failure(let error):
            switch error {
            case .notFound( _, _):
                return
            default:
                XCTFail()
            }
        }
    }
    
    func testGetDataForAccount() async {
        let responseEnum = await sdk.accounts.getDataForAccount(accountId: testSuccessAccountId, key:"soneso")
        switch responseEnum {
        case .success(let details):
            XCTAssertEqual(details.value.base64Decoded(), "is fun")
        case .failure(let error):
            StellarSDKLog.printHorizonRequestErrorMessage(tag:"testGetDataForAccount()", horizonRequestError: error)
            XCTFail()
        }
    }
}
