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
final class EchoTests: XCTestCase
{
    private var session: UUHttpSession { UUHttpSession() }
    
    // MARK: GET
    
    func test_get_echoesQueryArgs_defaultStatus()
    {
        let cfg = UULoadNetworkingTestConfig()
        let exp = uuExpectationForMethod()
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "GetValue"
        queryArgs["fieldTwo"] = 42
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyResponse>(
            url: cfg.echoControllerJsonUrl,
            method: .get,
            queryArguments: queryArgs)
        
        _ = session.executeCodableRequest(req)
        { (response: EchoObject?, err: Error?) in
            XCTAssertNil(err)
            XCTAssertNotNil(response)
            XCTAssertEqual(response?.fieldOne, "GetValue")
            XCTAssertEqual(response?.fieldTwo, 42)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_get_customStatusCodeHeader()
    {
        let cfg = UULoadNetworkingTestConfig()
        let exp = uuExpectationForMethod()
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "StatusTest"
        queryArgs["fieldTwo"] = 1
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyResponse>(
            url: cfg.echoControllerJsonUrl,
            method: .get,
            queryArguments: queryArgs,
            headers: echoHeaders(statusCode: 201))
        
        _ = session.executeCodableRequest(req)
        { (response: EchoObject?, err: Error?) in
            XCTAssertNil(err)
            XCTAssertNotNil(response)
            XCTAssertEqual(response?.fieldOne, "StatusTest")
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_get_returnObjectCountHeader()
    {
        let cfg = UULoadNetworkingTestConfig()
        let exp = uuExpectationForMethod()
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "ArrayTest"
        queryArgs["fieldTwo"] = 7
        
        let req = UUCodableHttpRequest<[EchoObject], UUEmptyResponse>(
            url: cfg.echoControllerJsonUrl,
            method: .get,
            queryArguments: queryArgs,
            headers: echoHeaders(returnObjectCount: 3))
        
        _ = session.executeCodableRequest(req)
        { (response: [EchoObject]?, err: Error?) in
            XCTAssertNil(err)
            XCTAssertNotNil(response)
            XCTAssertEqual(response?.count, 3)
            XCTAssertTrue(response?.allSatisfy { $0.fieldOne == "ArrayTest" && $0.fieldTwo == 7 } ?? false)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_get_nonSuccessStatusCodeHeader()
    {
        let cfg = UULoadNetworkingTestConfig()
        let exp = uuExpectationForMethod()
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyResponse>(
            url: cfg.echoControllerJsonUrl,
            method: .get,
            queryArguments: ["fieldOne": "ErrorPath", "fieldTwo": 0],
            headers: echoHeaders(statusCode: 404))
        
        _ = session.executeRequest(req)
        { response in
            XCTAssertNotNil(response.httpError)
            XCTAssertEqual(response.httpStatusCode, 404)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    // MARK: POST
    
    func test_post_echoesJsonBody()
    {
        let cfg = UULoadNetworkingTestConfig()
        let exp = uuExpectationForMethod()
        
        let payload = EchoObject(fieldOne: "PostValue", fieldTwo: 99)
        let body = try! JSONEncoder().encode(payload)
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyResponse>(
            url: cfg.echoControllerJsonUrl,
            method: .post,
            headers: echoHeaders(),
            body: body,
            contentType: "application/json")
        
        _ = session.executeCodableRequest(req)
        { (response: EchoObject?, err: Error?) in
            XCTAssertNil(err)
            XCTAssertNotNil(response)
            XCTAssertEqual(response?.fieldOne, "PostValue")
            XCTAssertEqual(response?.fieldTwo, 99)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_post_statusCodeAndReturnObjectCountHeaders()
    {
        let cfg = UULoadNetworkingTestConfig()
        let exp = uuExpectationForMethod()
        
        let payload = EchoObject(fieldOne: "PostArray", fieldTwo: 2)
        let body = try! JSONEncoder().encode(payload)
        
        let req = UUCodableHttpRequest<[EchoObject], UUEmptyResponse>(
            url: cfg.echoControllerJsonUrl,
            method: .post,
            headers: echoHeaders(statusCode: 200, returnObjectCount: 2),
            body: body,
            contentType: "application/json")
        
        _ = session.executeCodableRequest(req)
        { (response: [EchoObject]?, err: Error?) in
            XCTAssertNil(err)
            XCTAssertNotNil(response)
            XCTAssertEqual(response?.count, 2)
            XCTAssertTrue(response?.allSatisfy { $0.fieldOne == "PostArray" && $0.fieldTwo == 2 } ?? false)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    // MARK: PUT
    
    func test_put_echoesJsonBody()
    {
        let cfg = UULoadNetworkingTestConfig()
        let exp = uuExpectationForMethod()
        
        let payload = EchoObject(fieldOne: "PutValue", fieldTwo: 55)
        let body = try! JSONEncoder().encode(payload)
        
        let req = UUCodableHttpRequest<EchoObject, UUEmptyResponse>(
            url: cfg.echoControllerJsonUrl,
            method: .put,
            headers: echoHeaders(),
            body: body,
            contentType: "application/json")
        
        _ = session.executeCodableRequest(req)
        { (response: EchoObject?, err: Error?) in
            XCTAssertNil(err)
            XCTAssertNotNil(response)
            XCTAssertEqual(response?.fieldOne, "PutValue")
            XCTAssertEqual(response?.fieldTwo, 55)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_put_customStatusCodeAndReturnObjectCountHeaders()
    {
        let cfg = UULoadNetworkingTestConfig()
        let exp = uuExpectationForMethod()
        
        let payload = EchoObject(fieldOne: "PutArray", fieldTwo: 8)
        let body = try! JSONEncoder().encode(payload)
        
        let req = UUCodableHttpRequest<[EchoObject], UUEmptyResponse>(
            url: cfg.echoControllerJsonUrl,
            method: .put,
            headers: echoHeaders(statusCode: 202, returnObjectCount: 4),
            body: body,
            contentType: "application/json")
        
        _ = session.executeCodableRequest(req)
        { (response: [EchoObject]?, err: Error?) in
            XCTAssertNil(err)
            XCTAssertNotNil(response)
            XCTAssertEqual(response?.count, 4)
            XCTAssertTrue(response?.allSatisfy { $0.fieldOne == "PutArray" && $0.fieldTwo == 8 } ?? false)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
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
