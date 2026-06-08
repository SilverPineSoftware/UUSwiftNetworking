//
//  EchoTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/22/26.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

/// Integration tests against `EchoController` (`/echo/json`).
/// Optional request headers (see UUNetworkingTestServer `common.php`):
/// - `UU-Status-Code` — HTTP status returned by the server
/// - `UU-Return-Object-Count` — when > 1, response body is an array of that many copies
final class EchoTests: BaseOnlineTest
{
    // MARK: GET
    
    private var echoControllerJsonUrl: String
    {
        testConfig.echoControllerJsonUrl
    }
    
    func test_get_echoesQueryArgs_defaultStatus() async throws
    {
        let session = uuHttpSessionForTest
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "GetValue"
        queryArgs["fieldTwo"] = 42
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyCodable>(
            url: echoControllerJsonUrl,
            method: .get,
            queryArguments: queryArgs)
        
        let result = await session.executeCodableRequest(req)
        switch (result)
        {
            case .success(let response):
                XCTAssertEqual(response.fieldOne, "GetValue")
                XCTAssertEqual(response.fieldTwo, 42)
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
    
    func test_get_customStatusCodeHeader() async throws
    {
        let session = uuHttpSessionForTest
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "StatusTest"
        queryArgs["fieldTwo"] = 1
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyCodable>(
            url: echoControllerJsonUrl,
            method: .get,
            queryArguments: queryArgs,
            headers: echoHeaders(statusCode: 201))
        
        let result = await session.executeCodableRequest(req)
        switch (result)
        {
            case .success(let response):
                XCTAssertEqual(response.fieldOne, "StatusTest")
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
    
    func test_get_returnObjectCountHeader() async throws
    {
        let session = uuHttpSessionForTest
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "ArrayTest"
        queryArgs["fieldTwo"] = 7
        
        let req = UUCodableHttpRequest<[EchoObject], UUEmptyCodable>(
            url: echoControllerJsonUrl,
            method: .get,
            queryArguments: queryArgs,
            headers: echoHeaders(returnObjectCount: 3))
        
        let result = await session.executeCodableRequest(req)
        switch (result)
        {
            case .success(let response):
                XCTAssertEqual(response.count, 3)
                XCTAssertTrue(response.allSatisfy { $0.fieldOne == "ArrayTest" && $0.fieldTwo == 7 })
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
    
    func test_get_nonSuccessStatusCodeHeader() async throws
    {
        let session = uuHttpSessionForTest
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyCodable>(
            url: echoControllerJsonUrl,
            method: .get,
            queryArguments: ["fieldOne": "ErrorPath", "fieldTwo": 0],
            headers: echoHeaders(statusCode: 404))
        
        let result = await session.executeCodableRequest(req)
        switch (result)
        {
            case .success(let response):
                XCTFail("Unexpected success: \(response)")
            
            case .failure(let err):
                XCTAssertEqual(err.uuHttpStatusCode, 404)
        }
    }
    
    // MARK: POST
    
    func test_post_echoesJsonBody() async throws
    {
        let session = uuHttpSessionForTest
        
        let payload = EchoObject(fieldOne: "PostValue", fieldTwo: 99)
        let body = UUJsonBody(payload)
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyCodable>(
            url: echoControllerJsonUrl,
            method: .post,
            headers: echoHeaders(),
            body: body)
        
        let result = await session.executeCodableRequest(req)
        switch (result)
        {
            case .success(let response):
                XCTAssertEqual(response.fieldOne, "PostValue")
                XCTAssertEqual(response.fieldTwo, 99)
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
    
    func test_post_statusCodeAndReturnObjectCountHeaders() async throws
    {
        let session = uuHttpSessionForTest
        
        let payload = EchoObject(fieldOne: "PostArray", fieldTwo: 2)
        let body = UUJsonBody(payload)
        
        let req = UUCodableHttpRequest<[EchoObject], UUEmptyCodable>(
            url: echoControllerJsonUrl,
            method: .post,
            headers: echoHeaders(statusCode: 200, returnObjectCount: 2),
            body: body)
        
        let result = await session.executeCodableRequest(req)
        switch (result)
        {
            case .success(let response):
                XCTAssertEqual(response.count, 2)
                XCTAssertTrue(response.allSatisfy { $0.fieldOne == "PostArray" && $0.fieldTwo == 2 })
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
    
    // MARK: PUT
    
    func test_put_echoesJsonBody() async throws
    {
        let session = uuHttpSessionForTest
        
        let payload = EchoObject(fieldOne: "PutValue", fieldTwo: 55)
        let body = UUJsonBody(payload)
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyCodable>(
            url: echoControllerJsonUrl,
            method: .put,
            headers: echoHeaders(),
            body: body)
        
        let result = await session.executeCodableRequest(req)
        switch (result)
        {
            case .success(let response):
                XCTAssertEqual(response.fieldOne, "PutValue")
                XCTAssertEqual(response.fieldTwo, 55)
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
    
    func test_put_customStatusCodeAndReturnObjectCountHeaders() async throws
    {
        let session = uuHttpSessionForTest
        
        let payload = EchoObject(fieldOne: "PutArray", fieldTwo: 8)
        let body = UUJsonBody(payload)
        
        let req = UUCodableHttpRequest<[EchoObject], UUEmptyCodable>(
            url: echoControllerJsonUrl,
            method: .put,
            headers: echoHeaders(statusCode: 202, returnObjectCount: 4),
            body: body)
        
        let result = await session.executeCodableRequest(req)
        switch (result)
        {
            case .success(let response):
                XCTAssertEqual(response.count, 4)
                XCTAssertTrue(response.allSatisfy { $0.fieldOne == "PutArray" && $0.fieldTwo == 8 })
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
}

// MARK: - Helpers

private func echoHeaders(statusCode: Int? = nil, returnObjectCount: Int? = nil) -> UUHttpHeaders
{
    var headers = UUHttpHeaders()
    if let statusCode
    {
        headers["UU-Status-Code"] = statusCode
    }
    if let returnObjectCount
    {
        headers["UU-Return-Object-Count"] = returnObjectCount
    }
    return headers
}

private struct EchoObject: Codable, Equatable
{
    var fieldOne: String
    var fieldTwo: Int
}
