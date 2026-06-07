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

class UUHttpSessionStaticTests: BaseOnlineTest
{
    func test_getCodableObject() async throws
    {
        let cfg = try loadTestConfig()
        let url = cfg.echoJsonUrl
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "SomeValue"
        queryArgs["fieldTwo"] = 1234
        
        var headers = UUHttpHeaders()
        headers["UU-Return-Object-Count"] = 1
        
        let req = UUCodableHttpRequest<SimpleObject, UUEmptyCodable>(
            url: url,
            method: .get,
            queryArguments: queryArgs,
            headers: headers)
        
        let result = await UUHttpSession.executeCodableRequest(req)
        switch (result)
        {
            case .success(let obj):
                XCTAssertNotNil(obj)
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
    
    func test_getCodableArray() async throws
    {
        let cfg = try loadTestConfig()
        let url = cfg.echoJsonUrl
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "SomeValue"
        queryArgs["fieldTwo"] = 1234
        
        var headers = UUHttpHeaders()
        headers["UU-Return-Object-Count"] = 3
        
        let req = UUCodableHttpRequest<[SimpleObject], UUEmptyCodable>(
            url: url,
            method: .get,
            queryArguments: queryArgs,
            headers: headers)
        
        let result = await UUHttpSession.executeCodableRequest(req)
        switch (result)
        {
            case .success(let obj):
                XCTAssertNotNil(obj)
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
}


fileprivate class SimpleObject: Codable
{
    var fieldOne: String
    var fieldTwo: Int
}

