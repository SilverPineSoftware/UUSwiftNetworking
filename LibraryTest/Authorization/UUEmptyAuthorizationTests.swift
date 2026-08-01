//
//  UUEmptyAuthorizationTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/14/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUEmptyAuthorizationTests: XCTestCase
{
    private let testUrl = "https://api.example.com/token"

    // MARK: - formatAuthorization

    func test_formatAuthorization_returnsNil()
    {
        let authorization = UUEmptyAuthorization()

        XCTAssertNil(authorization.formatAuthorization())
    }

    func test_formatAuthorization_returnsNilEvenWhenBaseAuthorizationIsSet()
    {
        let authorization = UUEmptyAuthorization(scheme: "Bearer", authorization: "stale-token")

        XCTAssertNil(authorization.formatAuthorization())
    }

    // MARK: - attachAuthorization

    func test_attachAuthorization_doesNotAddAuthorizationHeader()
    {
        let authorization = UUEmptyAuthorization()
        let request = UUHttpRequest(url: testUrl)

        authorization.attachAuthorization(request)

        XCTAssertNil(request.headerFields[UUHttpHeader.authorization])
    }

    func test_attachAuthorization_doesNotModifyExistingAuthorizationHeader()
    {
        let authorization = UUEmptyAuthorization()
        let request = UUHttpRequest(url: testUrl)
        request.headerFields[UUHttpHeader.authorization] = "Bearer existing"

        authorization.attachAuthorization(request)

        XCTAssertEqual(request.headerFields[UUHttpHeader.authorization] as? String, "Bearer existing")
    }

    func test_buildURLRequest_doesNotAddAuthorizationHeader() async
    {
        let request = UUHttpRequest(url: testUrl)
        request.authorization = UUEmptyAuthorization()

        let urlRequest = await request.buildURLRequest()

        XCTAssertNotNil(urlRequest)
        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization))
    }

    // MARK: - UURemoteApi integration

    func test_prepareRequest_doesNotReplaceEmptyAuthorizationWithApiProvider() async
    {
        let apiProvider = UUStaticHttpAuthorizationProvider(
            UUBasicAuthorization(userName: "api", password: "secret"))
        let emptyAuthorization = UUEmptyAuthorization()
        let request = UUHttpRequest(url: testUrl)
        request.authorization = emptyAuthorization

        let api = TestRemoteApiForEmptyAuth()
        api.authorizationProvider = apiProvider

        await api.prepareRequest(request)

        XCTAssertTrue(request.authorization === emptyAuthorization)
    }

    func test_prepareRequest_emptyAuthorizationSkipsApiProviderOnNetworkRequest() async
    {
        let apiProvider = UUStaticHttpAuthorizationProvider(
            UUBasicAuthorization(userName: "api", password: "secret"))
        let request = UUHttpRequest(url: testUrl)
        request.authorization = UUEmptyAuthorization()

        let api = TestRemoteApiForEmptyAuth()
        api.authorizationProvider = apiProvider

        await api.prepareRequest(request)
        let urlRequest = await request.buildURLRequest()

        XCTAssertNil(urlRequest?.value(forHTTPHeaderField: UUHttpHeader.authorization))
    }
}

// MARK: - Test support

private final class TestRemoteApiForEmptyAuth: UURemoteApi
{
}
