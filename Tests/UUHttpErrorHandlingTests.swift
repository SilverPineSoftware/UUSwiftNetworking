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
    func test_noInternet()
    {
        // TODO: Write this test
        // Also TODO: How to test no internet in a unit test??
        
        XCTFail("Need to implement this test: \(#function)")
    }
    
    func test_cannotFindHost()
    {
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.doesNotExistUrl
        
        UUHttpSession.get(url: url)
        { response in
            
            UUAssertError(response, .cannotFindHost)
            
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_timedOut()
    {
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.timeoutUrl
        
        let timeout = 10
        var queryArgs = UUQueryStringArgs()
        queryArgs["timeout"] = timeout
        
        let request = UUHttpRequest(url: url, method: .get, queryArguments: queryArgs)
        request.timeout = TimeInterval(timeout / 2)
        
        _ = UUHttpSession.executeRequest(request)
        { response in
            
            UUAssertError(response, .timedOut)
            
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_httpFailure()
    {
        XCTFail("Need to implement this test: \(#function)")
    }
    
    func test_httpError()
    {
        XCTFail("Need to implement this test: \(#function)")
    }
    
    func test_userCanceled()
    {
        XCTFail("Need to implement this test: \(#function)")
    }
    
    func test_invalidRequest()
    {
        XCTFail("Need to implement this test: \(#function)")
    }
    
    func test_parseFailure_codable()
    {
        XCTFail("Need to implement this test: \(#function)")
    }
    
    
    
    /*
    public enum UUHttpSessionError : Int
    {
        // Returned when URLSession returns a non-nil error and the underlying
        // error domain is NSURLErrorDomain and the underlying error code is
        // NSURLErrorNotConnectedToInternet
        case noInternet = 0x1000

        // Returned when URLSession returns a non-nil error and the underlying
        // error domain is NSURLErrorDomain and the underlying error code is
        // NSURLErrorCannotFindHost
        case cannotFindHost = 0x1001

        // Returned when URLSession returns a non-nil error and the underlying
        // error domain is NSURLErrorDomain and the underlying error code is
        // NSURLErrorTimedOut
        case timedOut = 0x1002

        // Returned when URLSession completion block returns a non-nil Error, and
        // that error is not specifically mapped to a more common UUHttpSessionError
        // In this case, the underlying NSError is wrapped in the user info block
        // using the NSUnderlyingError key
        case httpFailure = 0x2000

        // Returned when the URLSession completion block returns with a nil Error
        // and an HTTP return code that is not 2xx
        case httpError = 0x2001

        // Returned when a user cancels an operation
        case userCancelled = 0x2002

        // The request URL and/or query string parameters resulted in an invalid
        // URL.
        case invalidRequest = 0x2003
        
        /**
         UU failed to parse a response.  See underlying error for more details
         */
        case parseFailure = 0x2004
    }*/
}
