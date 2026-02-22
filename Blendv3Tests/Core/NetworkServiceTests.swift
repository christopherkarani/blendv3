//
//  NetworkServiceTests.swift
//  Blendv3Tests
//
//  Created by Chris Karani on 22/05/2025.
//

import Testing
import Combine
@testable import Blendv3

struct NetworkServiceTests {
    
    // MARK: - Test Models
    struct TestResponse: Codable, Equatable {
        let id: Int
        let title: String
    }
    
    struct TestRequest: NetworkRequest {
        let baseURL: String = "https://api.example.com"
        let path: String = "/test"
        let method: HTTPMethod = .GET
        let headers: [String : String]? = nil
        let body: Data? = nil
    }
    
    @Test func networkErrorDescriptions() async throws {
        // Test error descriptions
        #expect(NetworkError.invalidURL.errorDescription == "Invalid URL")
        #expect(NetworkError.noData.errorDescription == "No data received")
        #expect(NetworkError.networkUnavailable.errorDescription == "Network unavailable")
        
        let serverError = NetworkError.serverError(404)
        #expect(serverError.errorDescription == "Server error with code: 404")
    }
    
    @Test func httpMethodRawValues() async throws {
        #expect(HTTPMethod.GET.rawValue == "GET")
        #expect(HTTPMethod.POST.rawValue == "POST")
        #expect(HTTPMethod.PUT.rawValue == "PUT")
        #expect(HTTPMethod.DELETE.rawValue == "DELETE")
    }
    
    @Test func testRequestProperties() async throws {
        // Given
        let request = TestRequest()
        
        // Then
        #expect(request.baseURL == "https://api.example.com")
        #expect(request.path == "/test")
        #expect(request.method == .GET)
        #expect(request.headers == nil)
        #expect(request.body == nil)
    }
    
    @Test func networkServiceInitialization() async throws {
        // Given/When
        let networkService = NetworkService()
        
        // Then - Should initialize without throwing
        #expect(networkService != nil)
    }
    
    // Note: For actual network request testing, we would typically use URLProtocol mocking
    // or dependency injection with a mock URLSession in a real-world scenario
}