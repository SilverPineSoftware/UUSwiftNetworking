//
//  UUHttpErrorHandlingTests.swift
//  UUSwiftNetworking
//  
//  Created by Ryan DeVore on 10/19/21.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

class UUHttpErrorHandlingTests: BaseOnlineTest
{
    func test_noInternet()
    {
        // TODO: Write this test
        // Also TODO: How to test no internet in a unit test??
        _ = XCTSkip("Need to implement this test: \(#function)")
    }
    
    func test_cannotFindHost() async throws
    {
        let session = uuHttpSessionForTest
        
        let cfg = try loadTestConfig()
        let url = cfg.doesNotExistUrl
        
        let request = UUHttpRequest(url: url)
        let response = await session.executeRequest(request)
        UUAssertResponseError(response, .cannotFindHost)
    }
    
    func test_timedOut() async throws
    {
        let session = uuHttpSessionForTest
        
        let cfg = try loadTestConfig()
        let url = cfg.timeoutUrl
        
        let timeout = 10
        var queryArgs = UUQueryStringArgs()
        queryArgs["timeout"] = timeout
        
        let request = UUHttpRequest(url: url, method: .get, queryArguments: queryArgs)
        request.timeout = TimeInterval(timeout / 2)
        
        UUTestLog("Starting request, timeout: \(request.timeout)")
        let response = await session.executeRequest(request)
        UUAssertResponseError(response, .timedOut)
    }
    
    func test_httpFailure() async throws
    {
        let session = uuHttpSessionForTest
        
        let cfg = try loadTestConfig()
        let url = cfg.redirectUrl
        
        let request = UUHttpRequest(url: url)
        let response = await session.executeRequest(request)
        UUAssertResponseError(response, .httpFailure)
    }
    
    func test_httpError() async throws
    {
        try await doStatusCodeTest(statusCode: 500, expectedError: .httpError)
    }
    
    /*func test_userCanceled() async
    {
        let session = uuHttpSessionForTest
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.timeoutUrl
        
        let timeout = 30
        var queryArgs = UUQueryStringArgs()
        queryArgs["timeout"] = (timeout * 60)
        
        let request = UUHttpRequest(url: url, method: .get, queryArguments: queryArgs)
        let response = await session.executeRequest(request)
        UUAssertResponseError(response, .userCancelled)
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 5)
        {
            UUTestLog("Canceling task")
            task.cancel()
        }
    }*/
    
    func test_invalidRequest() async
    {
        let session = uuHttpSessionForTest
        
        let request = UUHttpRequest(url: "?1234$%*()(")
        let response = await session.executeRequest(request)
        UUAssertResponseError(response, .invalidRequest, expectValidRequest: false)

    }
    
    func test_parseFailure_codable() async throws
    {
        let session = uuHttpSessionForTest
        XCTAssertNotNil(session)
        
        let cfg = try loadTestConfig()
        let url = cfg.invalidJsonUrl
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["stringField"] = "UnitTestString"
        queryArgs["numberField"] = 57
        
        let request = UUHttpRequest(url: url, method: .get, queryArguments: queryArgs)
        let handler = UUJsonCodableResponseHandler<FakeCodable, UUEmptyCodable>()

        request.responseHandler = handler
        
        let response = await session.executeRequest(request)
        UUAssertResponseError(response, .parseFailure)
    }
    
    func test_parseFailure_parserError() async throws
    {
        let session = uuHttpSessionForTest
        XCTAssertNotNil(session)
        
        let cfg = try loadTestConfig()
        let url = cfg.echoJsonUrl
        
        let request = UUHttpRequest(url: url, method: .get)
        
        let err = NSError(domain: "UnitTest", code: 1234, userInfo: nil)
        request.responseHandler = PassthroughResponseHandler(err)
        
        let response = await session.executeRequest(request)
        //UUAssertResponseError(response, .invalidRequest, expectValidRequest: false)
        XCTAssertNotNil(response.httpError)
        XCTAssertEqual((response.httpError! as NSError).domain, "UnitTest")
        XCTAssertEqual((response.httpError! as NSError).code, 1234)
    }
    
    func test_authorizationNeeded() async throws
    {
        try await doStatusCodeTest(statusCode: 401, expectedError: .authorizationNeeded)
    }
    
    func doStatusCodeTest(statusCode: Int, expectedError: UUHttpSessionError) async throws
    {
        let session = uuHttpSessionForTest
        XCTAssertNotNil(session)
        
        let cfg = try loadTestConfig()
        let url = cfg.echoJsonUrl
        
        var headers = UUHttpHeaders()
        headers["UU-Status-Code"] = statusCode
        
        let request = UUHttpRequest(url: url, method: .get, headers: headers)
        let response = await session.executeRequest(request)
        XCTAssertNotNil(response.httpError)
        XCTAssertNotNil(response.parsedResponse)
        UUAssertError(response.httpError, expectedError, expectValidRequest: true)

    }
}

fileprivate class FakeCodable: Codable
{
    var stringField: String
    var numberField: Int
}

fileprivate class PassthroughDataParser: UUHttpDataParser
{
    private var passthroughResponse: Any? = nil
    
    required init(_ response: Any?)
    {
        self.passthroughResponse = response
    }
    
    open func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
    {
        return self.passthroughResponse
    }
}

fileprivate class PassthroughResponseHandler: UUBaseResponseHandler
{
    private var passthroughResponse: Any? = nil
    
    required init(_ response: Any?)
    {
        self.passthroughResponse = response
        super.init()
    }
    
    required init()
    {
        super.init()
    }
    
    override var successParser: UUHttpDataParser
    {
        return PassthroughDataParser(passthroughResponse)
    }
    
    override var errorParser: UUHttpDataParser
    {
        return PassthroughDataParser(passthroughResponse)
    }
}
