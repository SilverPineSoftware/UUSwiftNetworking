//
//  UUHttpAuthorizationProviderTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/14/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUHttpAuthorizationProviderTests: XCTestCase
{
    private let testUrl = "https://api.example.com/resource"

    // MARK: - init / formatAuthorization

    func test_init_defaultsToBearerSchemeAndNilAuthorization()
    {
        let provider = UUHttpAuthorizationProvider()

        XCTAssertEqual(provider.scheme, "Bearer")
        XCTAssertNil(provider.authorization)
        XCTAssertNil(provider.formatAuthorization())
    }

    func test_formatAuthorization_returnsStoredAuthorization()
    {
        let provider = UUHttpAuthorizationProvider(authorization: "access-token")

        XCTAssertEqual(provider.formatAuthorization(), "access-token")
    }

    func test_formatAuthorization_returnsNilWhenAuthorizationIsNil()
    {
        let provider = UUHttpAuthorizationProvider(scheme: "Bearer", authorization: nil)

        XCTAssertNil(provider.formatAuthorization())
    }

    func test_formatAuthorization_reflectsUpdatedAuthorizationProperty()
    {
        let provider = UUHttpAuthorizationProvider(authorization: "first")
        provider.authorization = "second"

        XCTAssertEqual(provider.formatAuthorization(), "second")
    }

    // MARK: - attachAuthorization

    func test_attachAuthorization_addsBearerHeaderWhenAuthorizationIsSet() async
    {
        let provider = UUHttpAuthorizationProvider(authorization: "my-token")
        let request = UUHttpRequest(url: testUrl)

        await provider.attachAuthorization(request)

        XCTAssertEqual(request.headerFields[UUHttpHeader.authorization] as? String, "Bearer my-token")
    }

    func test_attachAuthorization_usesCustomScheme() async
    {
        let provider = UUHttpAuthorizationProvider(scheme: "Token", authorization: "abc123")
        let request = UUHttpRequest(url: testUrl)

        await provider.attachAuthorization(request)

        XCTAssertEqual(request.headerFields[UUHttpHeader.authorization] as? String, "Token abc123")
    }

    func test_attachAuthorization_doesNotAddHeaderWhenAuthorizationIsNil() async
    {
        let provider = UUHttpAuthorizationProvider()
        let request = UUHttpRequest(url: testUrl)

        await provider.attachAuthorization(request)

        XCTAssertNil(request.headerFields[UUHttpHeader.authorization])
    }

    func test_attachAuthorization_overwritesExistingAuthorizationHeader() async
    {
        let provider = UUHttpAuthorizationProvider(authorization: "new-token")
        let request = UUHttpRequest(url: testUrl)
        request.headerFields[UUHttpHeader.authorization] = "Bearer old-token"

        await provider.attachAuthorization(request)

        XCTAssertEqual(request.headerFields[UUHttpHeader.authorization] as? String, "Bearer new-token")
    }

    // MARK: - buildURLRequest

    func test_buildURLRequest_addsAuthorizationHeaderFromProvider() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorizationProvider = UUHttpAuthorizationProvider(authorization: "network-token")

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization), "Bearer network-token")
    }

    func test_buildURLRequest_omitsAuthorizationHeaderWhenCredentialIsNil() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorizationProvider = UUHttpAuthorizationProvider()

        let urlRequest = await request.buildURLRequest()

        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization))
    }
}
