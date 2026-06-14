//
//  UUBasicAuthorizationProviderTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/14/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUBasicAuthorizationProviderTests: XCTestCase
{
    private let testUrl = "https://api.example.com/resource"

    // MARK: - init / formatAuthorization

    func test_init_usesBasicScheme()
    {
        let provider = UUBasicAuthorizationProvider(userName: "user", password: "pass")

        XCTAssertEqual(provider.scheme, "Basic")
    }

    func test_formatAuthorization_returnsBase64EncodedCredentials()
    {
        let provider = UUBasicAuthorizationProvider(userName: "user", password: "pass")
        let expected = Data("user:pass".utf8).base64EncodedString()

        XCTAssertEqual(provider.formatAuthorization(), expected)
        XCTAssertEqual(expected, "dXNlcjpwYXNz")
    }

    func test_formatAuthorization_returnsNilWhenUserNameIsNil()
    {
        let provider = UUBasicAuthorizationProvider(userName: nil, password: "pass")

        XCTAssertNil(provider.formatAuthorization())
    }

    func test_formatAuthorization_returnsNilWhenPasswordIsNil()
    {
        let provider = UUBasicAuthorizationProvider(userName: "user", password: nil)

        XCTAssertNil(provider.formatAuthorization())
    }

    func test_formatAuthorization_reflectsUpdatedCredentials()
    {
        let provider = UUBasicAuthorizationProvider(userName: "first", password: "secret")
        provider.userName = "api-key"
        provider.password = "updated"

        let expected = Data("api-key:updated".utf8).base64EncodedString()
        XCTAssertEqual(provider.formatAuthorization(), expected)
    }

    // MARK: - attachAuthorization

    func test_attachAuthorization_addsBasicAuthorizationHeader() async
    {
        let provider = UUBasicAuthorizationProvider(userName: "my-api-key", password: "my-secret")
        let request = UUHttpRequest(url: testUrl)
        let expectedCredential = Data("my-api-key:my-secret".utf8).base64EncodedString()

        await provider.attachAuthorization(request)

        XCTAssertEqual(
            request.headerFields[UUHttpHeader.authorization] as? String,
            "Basic \(expectedCredential)"
        )
    }

    func test_attachAuthorization_doesNotAddHeaderWhenCredentialsAreIncomplete() async
    {
        let provider = UUBasicAuthorizationProvider(userName: "user", password: nil)
        let request = UUHttpRequest(url: testUrl)

        await provider.attachAuthorization(request)

        XCTAssertNil(request.headerFields[UUHttpHeader.authorization])
    }

    // MARK: - buildURLRequest

    func test_buildURLRequest_addsBasicAuthorizationHeaderFromProvider() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorizationProvider = UUBasicAuthorizationProvider(userName: "user", password: "pass")

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(
            urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization),
            "Basic dXNlcjpwYXNz"
        )
    }

    func test_buildURLRequest_omitsAuthorizationHeaderWhenCredentialsAreMissing() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorizationProvider = UUBasicAuthorizationProvider(userName: nil, password: nil)

        let urlRequest = await request.buildURLRequest()

        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization))
    }
}
