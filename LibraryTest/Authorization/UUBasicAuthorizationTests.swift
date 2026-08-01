//
//  UUBasicAuthorizationTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/14/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUBasicAuthorizationTests: XCTestCase
{
    private let testUrl = "https://api.example.com/resource"

    // MARK: - init / formatAuthorization

    func test_init_usesBasicScheme()
    {
        let authorization = UUBasicAuthorization(userName: "user", password: "pass")

        XCTAssertEqual(authorization.scheme, "Basic")
    }

    func test_formatAuthorization_returnsBase64EncodedCredentials()
    {
        let authorization = UUBasicAuthorization(userName: "user", password: "pass")
        let expected = Data("user:pass".utf8).base64EncodedString()

        XCTAssertEqual(authorization.formatAuthorization(), expected)
        XCTAssertEqual(expected, "dXNlcjpwYXNz")
    }

    func test_formatAuthorization_returnsNilWhenUserNameIsNil()
    {
        let authorization = UUBasicAuthorization(userName: nil, password: "pass")

        XCTAssertNil(authorization.formatAuthorization())
    }

    func test_formatAuthorization_returnsNilWhenPasswordIsNil()
    {
        let authorization = UUBasicAuthorization(userName: "user", password: nil)

        XCTAssertNil(authorization.formatAuthorization())
    }

    func test_formatAuthorization_reflectsUpdatedCredentials()
    {
        let authorization = UUBasicAuthorization(userName: "first", password: "secret")
        authorization.userName = "api-key"
        authorization.password = "updated"

        let expected = Data("api-key:updated".utf8).base64EncodedString()
        XCTAssertEqual(authorization.formatAuthorization(), expected)
    }

    // MARK: - attachAuthorization

    func test_attachAuthorization_addsBasicAuthorizationHeader()
    {
        let authorization = UUBasicAuthorization(userName: "my-api-key", password: "my-secret")
        let request = UUHttpRequest(url: testUrl)
        let expectedCredential = Data("my-api-key:my-secret".utf8).base64EncodedString()

        authorization.attachAuthorization(request)

        XCTAssertEqual(
            request.headerFields[UUHttpHeader.authorization] as? String,
            "Basic \(expectedCredential)"
        )
    }

    func test_attachAuthorization_doesNotAddHeaderWhenCredentialsAreIncomplete()
    {
        let authorization = UUBasicAuthorization(userName: "user", password: nil)
        let request = UUHttpRequest(url: testUrl)

        authorization.attachAuthorization(request)

        XCTAssertNil(request.headerFields[UUHttpHeader.authorization])
    }

    // MARK: - buildURLRequest

    func test_buildURLRequest_addsBasicAuthorizationHeaderFromAuthorization() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorization = UUBasicAuthorization(userName: "user", password: "pass")

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(
            urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization),
            "Basic dXNlcjpwYXNz"
        )
    }

    func test_buildURLRequest_omitsAuthorizationHeaderWhenCredentialsAreMissing() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorization = UUBasicAuthorization(userName: nil, password: nil)

        let urlRequest = await request.buildURLRequest()

        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization))
    }
}
