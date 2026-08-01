//
//  UUHttpAuthorizationTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/14/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUHttpAuthorizationTests: XCTestCase
{
    private let testUrl = "https://api.example.com/resource"

    // MARK: - init / formatAuthorization

    func test_init_defaultsToBearerSchemeAndNilAuthorization()
    {
        let authorization = UUHttpAuthorization()

        XCTAssertEqual(authorization.scheme, "Bearer")
        XCTAssertNil(authorization.authorization)
        XCTAssertNil(authorization.formatAuthorization())
    }

    func test_formatAuthorization_returnsStoredAuthorization()
    {
        let authorization = UUHttpAuthorization(authorization: "access-token")

        XCTAssertEqual(authorization.formatAuthorization(), "access-token")
    }

    func test_formatAuthorization_returnsNilWhenAuthorizationIsNil()
    {
        let authorization = UUHttpAuthorization(scheme: "Bearer", authorization: nil)

        XCTAssertNil(authorization.formatAuthorization())
    }

    func test_formatAuthorization_reflectsUpdatedAuthorizationProperty()
    {
        let authorization = UUHttpAuthorization(authorization: "first")
        authorization.authorization = "second"

        XCTAssertEqual(authorization.formatAuthorization(), "second")
    }
    
    func test_formatHeaderValue_includesScheme()
    {
        let authorization = UUHttpAuthorization(scheme: "Token", authorization: "abc123")
        
        XCTAssertEqual(authorization.formatHeaderValue(), "Token abc123")
    }

    // MARK: - attachAuthorization

    func test_attachAuthorization_addsBearerHeaderWhenAuthorizationIsSet()
    {
        let authorization = UUHttpAuthorization(authorization: "my-token")
        let request = UUHttpRequest(url: testUrl)

        authorization.attachAuthorization(request)

        XCTAssertEqual(request.headerFields[UUHttpHeader.authorization] as? String, "Bearer my-token")
    }

    func test_attachAuthorization_usesCustomScheme()
    {
        let authorization = UUHttpAuthorization(scheme: "Token", authorization: "abc123")
        let request = UUHttpRequest(url: testUrl)

        authorization.attachAuthorization(request)

        XCTAssertEqual(request.headerFields[UUHttpHeader.authorization] as? String, "Token abc123")
    }

    func test_attachAuthorization_doesNotAddHeaderWhenAuthorizationIsNil()
    {
        let authorization = UUHttpAuthorization()
        let request = UUHttpRequest(url: testUrl)

        authorization.attachAuthorization(request)

        XCTAssertNil(request.headerFields[UUHttpHeader.authorization])
    }

    func test_attachAuthorization_overwritesExistingAuthorizationHeader()
    {
        let authorization = UUHttpAuthorization(authorization: "new-token")
        let request = UUHttpRequest(url: testUrl)
        request.headerFields[UUHttpHeader.authorization] = "Bearer old-token"

        authorization.attachAuthorization(request)

        XCTAssertEqual(request.headerFields[UUHttpHeader.authorization] as? String, "Bearer new-token")
    }

    // MARK: - buildURLRequest

    func test_buildURLRequest_addsAuthorizationHeaderFromAuthorization() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorization = UUHttpAuthorization(authorization: "network-token")

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization), "Bearer network-token")
    }

    func test_buildURLRequest_omitsAuthorizationHeaderWhenCredentialIsNil() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorization = UUHttpAuthorization()

        let urlRequest = await request.buildURLRequest()

        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization))
    }
    
    // MARK: - UUStaticHttpAuthorizationProvider
    
    func test_staticProvider_loadAuthorization_returnsStoredAuthorization() async throws
    {
        let authorization = UUHttpAuthorization(authorization: "stored-token")
        let provider = UUStaticHttpAuthorizationProvider(authorization)
        
        let loaded = try await provider.loadAuthorization().get()
        
        XCTAssertTrue(loaded === authorization)
    }
    
    func test_staticProvider_saveAuthorization_replacesStoredAuthorization() async throws
    {
        let first = UUHttpAuthorization(authorization: "first")
        let second = UUHttpAuthorization(authorization: "second")
        let provider = UUStaticHttpAuthorizationProvider(first)
        
        let error = await provider.saveAuthorization(second)
        let loaded = try await provider.loadAuthorization().get()
        
        XCTAssertNil(error)
        XCTAssertTrue(loaded === second)
    }
    
    func test_staticProvider_clearAuthorization_removesStoredAuthorization() async throws
    {
        let provider = UUStaticHttpAuthorizationProvider(UUHttpAuthorization(authorization: "token"))
        
        let error = await provider.clearAuthorization()
        let loaded = try await provider.loadAuthorization().get()
        
        XCTAssertNil(error)
        XCTAssertNil(loaded)
    }
}
