//
//  UUHttpRequestTests.swift
//  LibraryTests
//
//  Created by Ryan DeVore on 6/30/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import XCTest
@testable import UUSwiftNetworking

final class UUHttpRequestTests: XCTestCase
{
    private let testUrl = "https://api.example.com/v1/items"

    // MARK: - URL construction

    func test_buildURLRequest_buildsRequestForValidHttpsUrl() async
    {
        let request = UUHttpRequest(url: testUrl)

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.url?.absoluteString, testUrl)
        XCTAssertEqual(urlRequest?.url?.scheme, "https")
        XCTAssertEqual(urlRequest?.url?.host, "api.example.com")
        XCTAssertEqual(urlRequest?.url?.path, "/v1/items")
    }

    func test_buildURLRequest_buildsRequestForHttpUrl() async
    {
        let request = UUHttpRequest(url: "http://api.example.com/status")

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.url?.absoluteString, "http://api.example.com/status")
    }

    func test_buildURLRequest_returnsNilWhenUrlIsRelative() async
    {
        let request = UUHttpRequest(url: "/v1/items")

        let urlRequest = await request.buildURLRequest()

        XCTAssertNil(urlRequest)
    }

    func test_buildURLRequest_returnsNilWhenUrlHasNoHost() async
    {
        let request = UUHttpRequest(url: "mailto:dev@example.com")

        let urlRequest = await request.buildURLRequest()

        XCTAssertNil(urlRequest)
    }

    func test_buildURLRequest_percentEncodesQueryItemNames() async
    {
        let request = UUHttpRequest(
            url: "https://api.example.com",
            queryItems: [
                URLQueryItem(name: "bad space", value: "value")
            ]
        )

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.url?.absoluteString, "https://api.example.com?bad%20space=value")
    }

    // MARK: - Query items

    func test_buildURLRequest_appendsQueryItems() async throws
    {
        let request = UUHttpRequest(
            url: testUrl,
            queryItems: [
                URLQueryItem(name: "search", value: "hello world"),
                URLQueryItem(name: "page", value: "2")
            ]
        )

        let urlRequest = await request.buildURLRequest()
        let components = URLComponents(url: try XCTUnwrap(urlRequest?.url), resolvingAgainstBaseURL: false)

        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "search" })?.value, "hello world")
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "page" })?.value, "2")
        XCTAssertEqual(urlRequest?.url?.absoluteString, "https://api.example.com/v1/items?search=hello%20world&page=2")
    }

    func test_buildURLRequest_replacesExistingQueryWithProvidedQueryItems() async throws
    {
        let request = UUHttpRequest(
            url: "https://api.example.com/v1/items?old=true",
            queryItems: [
                URLQueryItem(name: "new", value: "true")
            ]
        )

        let urlRequest = await request.buildURLRequest()
        let components = URLComponents(url: try XCTUnwrap(urlRequest?.url), resolvingAgainstBaseURL: false)

        XCTAssertNil(components?.queryItems?.first(where: { $0.name == "old" }))
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "new" })?.value, "true")
    }

    func test_buildURLRequest_removesExistingQueryWhenQueryItemsIsEmptyArray() async
    {
        let request = UUHttpRequest(
            url: "https://api.example.com/v1/items?old=true",
            queryItems: []
        )

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.url?.absoluteString, "https://api.example.com/v1/items?")
        XCTAssertEqual(urlRequest?.url?.query, "")
    }

    func test_buildURLRequest_removesExistingQueryWhenQueryItemsIsNil() async
    {
        let request = UUHttpRequest(url: "https://api.example.com/v1/items?old=true")

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.url?.absoluteString, "https://api.example.com/v1/items")
    }

    func test_buildURLRequest_supportsQueryItemWithoutValue() async
    {
        let request = UUHttpRequest(
            url: testUrl,
            queryItems: [
                URLQueryItem(name: "debug", value: nil)
            ]
        )

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.url?.absoluteString, "https://api.example.com/v1/items?debug")
    }

    // MARK: - Request properties

    func test_buildURLRequest_appliesHttpMethod() async
    {
        let methods: [UUHttpMethod] = [.get, .post, .put, .delete, .head, .patch]

        for method in methods
        {
            let request = UUHttpRequest(url: testUrl, method: method)

            let urlRequest = await request.buildURLRequest()

            XCTAssertEqual(urlRequest?.httpMethod, method.rawValue)
        }
    }

    func test_buildURLRequest_appliesTimeoutAndCachePolicy() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.timeout = 12.5
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.timeoutInterval, 12.5)
        XCTAssertEqual(urlRequest?.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
    }

    func test_buildURLRequest_doesNotSetHttpBody() async
    {
        let payload = Data("hello".utf8)
        let request = UUHttpRequest(
            url: testUrl,
            method: .post,
            body: UUHttpBody(contentType: UUContentType.textPlain, content: payload)
        )

        let urlRequest = await request.buildURLRequest()

        XCTAssertNil(urlRequest?.httpBody)
        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.contentType))
        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.contentLength))
    }

    // MARK: - Headers

    func test_buildURLRequest_appliesStringHeaders() async
    {
        let request = UUHttpRequest(
            url: testUrl,
            headers: [
                "Accept": UUContentType.applicationJson,
                "X-Trace-Id": "trace-123"
            ]
        )

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.value(forHTTPHeaderField: "Accept"), UUContentType.applicationJson)
        XCTAssertEqual(urlRequest?.value(forHTTPHeaderField: "X-Trace-Id"), "trace-123")
    }

    func test_buildURLRequest_convertsNonStringHeaderKeysAndValues() async
    {
        let request = UUHttpRequest(
            url: testUrl,
            headers: [
                42: 9001,
                "Retry-After": 30
            ]
        )

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.value(forHTTPHeaderField: "42"), "9001")
        XCTAssertEqual(urlRequest?.value(forHTTPHeaderField: "Retry-After"), "30")
    }

    func test_buildURLRequest_appliesHeadersAddedByAuthorizationProvider() async
    {
        let provider = HeaderAddingAuthorizationProvider(
            key: "X-Provider",
            value: "provider-value"
        )
        let request = UUHttpRequest(url: testUrl)
        request.authorizationProvider = provider

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(provider.attachCount, 1)
        XCTAssertEqual(urlRequest?.value(forHTTPHeaderField: "X-Provider"), "provider-value")
    }

    func test_buildURLRequest_authorizationProviderCanOverwriteExistingHeaderBeforeHeadersAreApplied() async
    {
        let provider = HeaderAddingAuthorizationProvider(
            key: UUHttpHeader.authorization,
            value: "Bearer new-token"
        )
        let request = UUHttpRequest(
            url: testUrl,
            headers: [
                UUHttpHeader.authorization: "Bearer old-token"
            ]
        )
        request.authorizationProvider = provider

        let urlRequest = await request.buildURLRequest()

        XCTAssertEqual(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization), "Bearer new-token")
    }
}

private final class HeaderAddingAuthorizationProvider: UUHttpAuthorizationProvider
{
    private let key: String
    private let value: String
    private(set) var attachCount = 0

    init(key: String, value: String)
    {
        self.key = key
        self.value = value
        super.init()
    }

    override func attachAuthorization(_ request: UUHttpRequest) async
    {
        attachCount += 1
        request.headerFields[key] = value
    }
}
