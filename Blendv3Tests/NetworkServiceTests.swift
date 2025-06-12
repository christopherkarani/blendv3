//
//  NetworkServiceTests.swift
//  Blendv3Tests
//
//  Unit tests for NetworkService demonstrating improved testability
//

import XCTest
import Combine
@testable import Blendv3

final class NetworkServiceTests: XCTestCase {
    
    private var sut: NetworkService!
    private var mockSession: URLSession!
    private var mockKeyProvider: MockKeyProvider!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Setup mock URLSession
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)
        
        // Setup mock key provider
        mockKeyProvider = MockKeyProvider()
        
        // Initialize system under test
        sut = NetworkService(
            session: mockSession,
            keyProvider: mockKeyProvider,
            baseURL: "https://api.test.com"
        )
        
        cancellables = []
    }
    
    override func tearDown() {
        sut = nil
        mockSession = nil
        mockKeyProvider = nil
        cancellables = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }
    
    // MARK: - Request Tests
    
    func testRequestSuccess() {
        // Given
        let expectation = XCTestExpectation(description: "Request completes")
        let testResponse = TestResponse(id: 123, name: "Test")
        let responseData = try! JSONEncoder().encode(testResponse)
        
        MockURLProtocol.requestHandler = { request in
            // Verify request headers
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }
        
        let endpoint = Endpoint(
            path: "/test",
            method: .get,
            headers: nil,
            body: nil,
            queryItems: nil
        )
        
        // When
        sut.request(endpoint)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Request should not fail")
                    }
                },
                receiveValue: { (response: TestResponse) in
                    // Then
                    XCTAssertEqual(response.id, 123)
                    XCTAssertEqual(response.name, "Test")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRequestUnauthorized() {
        // Given
        let expectation = XCTestExpectation(description: "Request fails with unauthorized")
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        
        let endpoint = Endpoint(
            path: "/test",
            method: .get,
            headers: nil,
            body: nil,
            queryItems: nil
        )
        
        // When
        sut.request(endpoint)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Then
                        XCTAssertEqual(error, NetworkError.unauthorized)
                        expectation.fulfill()
                    }
                },
                receiveValue: { (_: TestResponse) in
                    XCTFail("Request should fail")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Smart Contract Tests
    
    func testCallSmartContract() {
        // Given
        let expectation = XCTestExpectation(description: "Smart contract call completes")
        let responseData = Data("0x123abc".utf8)
        
        MockURLProtocol.requestHandler = { request in
            // Verify contract-specific headers
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Contract-Address"), "0xcontract123")
            
            // Verify request body contains contract data
            let body = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            XCTAssertEqual(body["method"] as? String, "transfer")
            XCTAssertEqual(body["address"] as? String, "0xcontract123")
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }
        
        let method = SmartContractMethod(
            name: "transfer",
            parameters: ["to": "0xrecipient", "amount": 100],
            gasLimit: 21000,
            value: nil
        )
        
        // When
        sut.callSmartContract(method)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Contract call should not fail")
                    }
                },
                receiveValue: { data in
                    // Then
                    XCTAssertEqual(String(data: data, encoding: .utf8), "0x123abc")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSimulateContract() {
        // Given
        let expectation = XCTestExpectation(description: "Contract simulation completes")
        let simulationResult = SimulationResult(
            success: true,
            gasUsed: 21000,
            output: "0xoutput",
            error: nil
        )
        let responseData = try! JSONEncoder().encode(simulationResult)
        
        MockURLProtocol.requestHandler = { request in
            // Verify simulation endpoint
            XCTAssertTrue(request.url!.absoluteString.contains("/contract/simulate"))
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }
        
        let method = SmartContractMethod(
            name: "estimateTransfer",
            parameters: ["to": "0xrecipient", "amount": 100],
            gasLimit: nil,
            value: nil
        )
        
        // When
        sut.simulateContract(method)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Simulation should not fail")
                    }
                },
                receiveValue: { result in
                    // Then
                    XCTAssertTrue(result.success)
                    XCTAssertEqual(result.gasUsed, 21000)
                    XCTAssertEqual(result.output, "0xoutput")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Test Helpers

private struct TestResponse: Codable, Equatable {
    let id: Int
    let name: String
}

private final class MockKeyProvider: KeyProviderProtocol {
    var apiKey: String = "test-api-key"
    var privateKey: String? = "test-private-key"
    var contractAddress: String? = "0xcontract123"
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable")
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}