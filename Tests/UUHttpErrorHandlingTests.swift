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

class UUHttpErrorHandlingTests: XCTestCase
{
    private var uuHttpSessionForTest: UUHttpSession
    {
        return UUHttpSession.shared
    }
    
    func test_noInternet()
    {
        // TODO: Write this test
        // Also TODO: How to test no internet in a unit test??
        
        XCTFail("Need to implement this test: \(#function)")
    }
    
    func test_cannotFindHost()
    {
        let session = uuHttpSessionForTest
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.doesNotExistUrl
        
        let request = UUHttpRequest(url: url)
        _ = session.executeRequest(request)
        { response in
            
            UUAssertResponseError(response, .cannotFindHost)
            
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_timedOut()
    {
        let session = uuHttpSessionForTest
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.timeoutUrl
        
        let timeout = 10
        var queryArgs = UUQueryStringArgs()
        queryArgs["timeout"] = timeout
        
        let request = UUHttpRequest(url: url, method: .get, queryArguments: queryArgs)
        request.timeout = TimeInterval(timeout / 2)
        
        _ = session.executeRequest(request)
        { response in
            
            UUAssertResponseError(response, .timedOut)
            
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_httpFailure()
    {
        let session = uuHttpSessionForTest
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.redirectUrl
        
        let request = UUHttpRequest(url: url)
        _ = session.executeRequest(request)
        { response in
            
            UUAssertResponseError(response, .httpFailure)
            
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_httpError()
    {
        doStatusCodeTest(statusCode: 500, expectedError: .httpError)
    }
    
    func test_userCanceled()
    {
        let session = uuHttpSessionForTest
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.timeoutUrl
        
        let timeout = 30
        var queryArgs = UUQueryStringArgs()
        queryArgs["timeout"] = (timeout * 60)
        
        let request = UUHttpRequest(url: url, method: .get, queryArguments: queryArgs)
        
        let task = session.executeRequest(request)
        { response in
            
            UUAssertResponseError(response, .userCancelled)
            
            exp.fulfill()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5)
        {
            NSLog("Canceling task")
            task.cancel()
        }
        
        uuWaitForExpectations()
    }
    
    func test_invalidRequest()
    {
        let session = uuHttpSessionForTest
        
        let exp = uuExpectationForMethod()
        
        let request = UUHttpRequest(url: "?1234$%*()(")
        _ = session.executeRequest(request)
        { response in
            
            UUAssertResponseError(response, .invalidRequest, expectValidRequest: false)
            
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_parseFailure_codable()
    {
        let session = uuHttpSessionForTest
        XCTAssertNotNil(session)
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.invalidJsonUrl
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["stringField"] = "UnitTestString"
        queryArgs["numberField"] = 57
        
        let request = UUHttpRequest(url: url, method: .get, queryArguments: queryArgs)
        request.responseHandler = UUJsonCodableResponseParser<FakeCodable>()
        
        _ = session.executeRequest(request)
        { response in
            
            UUAssertResponseError(response, .parseFailure)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_parseFailure_parserError()
    {
        let session = uuHttpSessionForTest
        XCTAssertNotNil(session)
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.echoJsonUrl
        
        let request = UUHttpRequest(url: url, method: .get)
        
        let err = NSError(domain: "UnitTest", code: 1234, userInfo: nil)
        request.responseHandler = PassthroughResponseParser(err)
        
        _ = session.executeRequest(request)
        { response in
            
            XCTAssertNotNil(response.httpError)
            XCTAssertEqual((response.httpError! as NSError).domain, "UnitTest")
            XCTAssertEqual((response.httpError! as NSError).code, 1234)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_authorizationNeeded()
    {
        doStatusCodeTest(statusCode: 401, expectedError: .authorizationNeeded)
    }
    
    func doStatusCodeTest(statusCode: Int, expectedError: UUHttpSessionError)
    {
        let session = uuHttpSessionForTest
        XCTAssertNotNil(session)
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.echoJsonUrl
        
        var headers = UUHttpHeaders()
        headers["UU-Status-Code"] = statusCode
        
        let request = UUHttpRequest(url: url, method: .get, headers: headers)
        
        _ = session.executeRequest(request)
        { response in
            
            XCTAssertNotNil(response.httpError)
            XCTAssertNotNil(response.parsedResponse)
            UUAssertError(response.httpError, expectedError, expectValidRequest: true)
            
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
}

fileprivate class FakeCodable: Codable
{
    var stringField: String
    var numberField: Int
}

fileprivate class PassthroughResponseParser: UUJsonResponseHandler
{
    private var passthroughResponse: Any? = nil
    
    required init(_ response: Any?)
    {
        self.passthroughResponse = response
        super.init()
    }
    
    override func parseResponse(_ data: Data, _ response: HTTPURLResponse, _ request: URLRequest) -> Any?
    {
        return self.passthroughResponse
    }
    
}
