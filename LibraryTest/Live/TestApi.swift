//
//  TestApi.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import Foundation
import UUSwiftCore
@testable import UUSwiftNetworking

struct TestApiError: Codable, Equatable
{
    var errorCode: Int = 0
    var errorMessage: String = ""
}

struct TestApiObject: Codable, Equatable
{
    var id: String = ""
    var name: String = ""
    var data: String = ""
}

/// Live integration API against `TestController` on the networking test server.
final class TestApi: UURemoteApi
{
    private let apiUrl: String

    init(baseUrl: String, session: UUHttpSession = UUHttpSession())
    {
        apiUrl = baseUrl
        
        super.init()
        
        
        self.session = session
        //super.init(session: session)
    }

    func getObject(_ echo: TestApiObject?) async -> Result<TestApiObject, Error>
    {
        var queryArgs: UUQueryStringArgs = [:]
        if let echo
        {
            if !echo.id.isEmpty { queryArgs["id"] = echo.id }
            if !echo.name.isEmpty { queryArgs["name"] = echo.name }
            if !echo.data.isEmpty { queryArgs["data"] = echo.data }
        }

        let request = UUCodableHttpRequest<TestApiObject, TestApiError>(
            url: "\(apiUrl)/single",
            queryArguments: queryArgs
        )

        return await executeCodableRequest(request)
    }

    func getArray(count: Int) async -> Result<[TestApiObject], Error>
    {
        let request = UUCodableHttpRequest<[TestApiObject], TestApiError>(
            url: "\(apiUrl)/multiple",
            queryArguments: ["count": "\(count)"]
        )

        return await executeCodableRequest(request)
    }

    func postObject(_ object: TestApiObject) async -> Result<TestApiObject, Error>
    {
        let body = UUJsonBody(object)
        let request = UUCodableHttpRequest<TestApiObject, TestApiError>(
            url: "\(apiUrl)/single",
            method: .post,
            body: body
        )

        return await executeCodableRequest(request)
    }

    func postArray(_ objects: [TestApiObject]) async -> Result<[TestApiObject], Error>
    {
        let body = UUJsonBody(objects)
        let request = UUCodableHttpRequest<[TestApiObject], TestApiError>(
            url: "\(apiUrl)/single",
            method: .post,
            body: body
        )

        return await executeCodableRequest(request)
    }
}
