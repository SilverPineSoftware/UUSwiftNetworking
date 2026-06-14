//
//  UUEmptyAuthorizationProviderTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/14/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUEmptyAuthorizationProviderTests: XCTestCase
{
    private let testUrl = "https://api.example.com/token"

    // MARK: - formatAuthorization

    func test_formatAuthorization_returnsNil()
    {
        let provider = UUEmptyAuthorizationProvider()

        XCTAssertNil(provider.formatAuthorization())
    }

    func test_formatAuthorization_returnsNilEvenWhenBaseAuthorizationIsSet()
    {
        let provider = UUEmptyAuthorizationProvider(scheme: "Bearer", authorization: "stale-token")

        XCTAssertNil(provider.formatAuthorization())
    }

    // MARK: - attachAuthorization

    func test_attachAuthorization_doesNotAddAuthorizationHeader() async
    {
        let provider = UUEmptyAuthorizationProvider()
        let request = UUHttpRequest(url: testUrl)

        await provider.attachAuthorization(request)

        XCTAssertNil(request.headerFields[UUHttpHeader.authorization])
    }

    func test_attachAuthorization_doesNotModifyExistingAuthorizationHeader() async
    {
        let provider = UUEmptyAuthorizationProvider()
        let request = UUHttpRequest(url: testUrl)
        request.headerFields[UUHttpHeader.authorization] = "Bearer existing"

        await provider.attachAuthorization(request)

        XCTAssertEqual(request.headerFields[UUHttpHeader.authorization] as? String, "Bearer existing")
    }

    func test_buildURLRequest_doesNotAddAuthorizationHeader() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorizationProvider = UUEmptyAuthorizationProvider()

        let urlRequest = await request.buildURLRequest()

        XCTAssertNotNil(urlRequest)
        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization))
    }

    // MARK: - UURemoteApi integration

    func test_prepareRequest_doesNotReplaceEmptyAuthorizationProviderWithApiConfig() async
    {
        let apiProvider = UUBasicAuthorizationProvider(userName: "api", password: "secret")
        let emptyProvider = UUEmptyAuthorizationProvider()
        let request = UUHttpRequest(url: testUrl)
        request.authorizationProvider = emptyProvider

        let api = TestRemoteApiForEmptyAuth()
        api.config = UURemoteApiConfig(authorizationProvider: apiProvider)

        await api.prepareRequest(request)

        XCTAssertTrue(request.authorizationProvider === emptyProvider)
    }

    func test_prepareRequest_emptyProviderSkipsApiAuthorizationOnNetworkRequest() async
    {
        let apiProvider = UUBasicAuthorizationProvider(userName: "api", password: "secret")
        let emptyProvider = UUEmptyAuthorizationProvider()
        let request = UUHttpRequest(url: testUrl)
        request.authorizationProvider = emptyProvider

        let api = TestRemoteApiForEmptyAuth()
        api.config = UURemoteApiConfig(authorizationProvider: apiProvider)

        await api.prepareRequest(request)
        let urlRequest = await request.buildURLRequest()

        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization))
    }
}

// MARK: - Test support

private final class TestRemoteApiForEmptyAuth: UURemoteApi
{
}
