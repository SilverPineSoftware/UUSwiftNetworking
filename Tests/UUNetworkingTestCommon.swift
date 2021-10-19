//
//  UUNetworkingTestCommon.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/19/21.
//

import Foundation
import XCTest
import UUSwiftNetworking

class Constants
{
    static let nonExistantHostUrl = "http://this.is.a.fake.url/non_existent.jpg"
    static let timeoutUrl = "https://spsw.io/uu/timeout.php"
    
    static let imageGetUrl = "http://publicdomainarchive.com/?ddownload=47473"
    //private static let testUrl : String = "http://publicdomainarchive.com/?ddownload=47473"
}

func UUAssertError(_ response: UUHttpResponse, _ expectedErrorCode: UUHttpSessionError)
{
    XCTAssertNotNil(response.httpError)
    XCTAssertNil(response.parsedResponse)
    
    guard let err = response.httpError else
    {
        XCTFail("Expect error to be non nil")
        return
    }
    
    let e = err as NSError
    XCTAssertEqual(e.domain, UUHttpSessionErrorDomain, "Error domain does not match")
    XCTAssertEqual(e.code, expectedErrorCode.rawValue, "Error code does not match")
    
    let requestMethod = e.userInfo[UUHttpSessionErrorHttpMethodKey] as? String
    XCTAssertNotNil(requestMethod)
    
    let requestUrl = e.userInfo[UUHttpSessionErrorRequestUrlKey] as? String
    XCTAssertNotNil(requestUrl)
}
