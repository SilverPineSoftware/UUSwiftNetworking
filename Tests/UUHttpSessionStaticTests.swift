//
//  UUHttpSessionStaticTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/22/21.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

class UUHttpSessionStaticTests: XCTestCase
{
    func test_getCodableObject()
    {
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.echoJsonUrl
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "SomeValue"
        queryArgs["fieldTwo"] = 1234
        
        var headers = UUHttpHeaders()
        headers["UU-Return-Object-Count"] = 1
        
        let req = UUCodableHttpRequest<SimpleObject, UUEmptyResponse>(
            url: url,
            method: .get,
            queryArguments: queryArgs,
            headers: headers)
        
        UUHttpSession.executeCodableRequest(req)
        { (response: SimpleObject?, err: Error?) in
            
            XCTAssertNotNil(response)
            XCTAssertNil(err)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_getCodableArray()
    {
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.echoJsonUrl
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "SomeValue"
        queryArgs["fieldTwo"] = 1234
        
        var headers = UUHttpHeaders()
        headers["UU-Return-Object-Count"] = 3
        
        let req = UUCodableHttpRequest<[SimpleObject], UUEmptyResponse>(
            url: url,
            method: .get,
            queryArguments: queryArgs,
            headers: headers)
        
        UUHttpSession.executeCodableRequest(req)
        { (response: [SimpleObject]?, err: Error?) in
            
            XCTAssertNotNil(response)
            XCTAssertNil(err)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
}


fileprivate class SimpleObject: Codable
{
    var fieldOne: String
    var fieldTwo: Int
}

