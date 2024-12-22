//
//  UUNetworkingTestCommon.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/19/21.
//

import Foundation
import XCTest
import UUSwiftCore
import UUSwiftNetworking

struct Constants
{
    static let nonExistantHostUrl = "http://this.is.a.fake.url/non_existent.jpg"
    static let timeoutUrl = "https://spsw.io/uu/timeout.php"
    
    static let imageGetUrl = "http://publicdomainarchive.com/?ddownload=47473"
    //private static let testUrl : String = "http://publicdomainarchive.com/?ddownload=47473"
}

func UUSetupTestLogging()
{
    let logger = UULogger.console
    logger.logLevel = .verbose
    
    UULog.setLogger(logger)
    
}

func UUAssertResponseError(_ response: UUHttpResponse, _ expectedErrorCode: UUHttpSessionError, expectValidRequest: Bool = true)
{
    XCTAssertNotNil(response.httpError)
    XCTAssertNil(response.parsedResponse)
    UUAssertError(response.httpError, expectedErrorCode, expectValidRequest: expectValidRequest)
}

func UUAssertError(_ error: Error?, _ expectedErrorCode: UUHttpSessionError, expectValidRequest: Bool = true)
{
    XCTAssertNotNil(error)
    let err = error!
    
    let e = err as NSError
    XCTAssertEqual(e.domain, UUHttpSessionErrorDomain, "Error domain does not match")
    XCTAssertEqual(e.code, expectedErrorCode.rawValue, "Error code does not match")
    
    if (expectValidRequest)
    {
        let requestMethod = e.userInfo[UUHttpSessionErrorHttpMethodKey] as? String
        XCTAssertNotNil(requestMethod)
    
        let requestUrl = e.userInfo[UUHttpSessionErrorRequestUrlKey] as? String
        XCTAssertNotNil(requestUrl)
    }
}

