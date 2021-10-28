//
//  UUHttpResponse.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import UUSwiftCore

public class UUHttpResponse : NSObject
{
    public let httpRequest: UUHttpRequest
    public let httpResponse: HTTPURLResponse?
    public let httpError: Error?
	public let parsedResponse: Any?
    public let rawResponse: Data?
    public let endTime: TimeInterval

    required init(
        request: UUHttpRequest,
        response: HTTPURLResponse? = nil,
        error: Error? = nil,
        rawResponse: Data? = nil,
        parsedResponse: Any? = nil)
	{
        self.httpRequest = request
        self.httpResponse = response
        self.httpError = error
        self.rawResponse = rawResponse
        self.parsedResponse = parsedResponse
        self.endTime = Date.timeIntervalSinceReferenceDate
	}
    
    // MARK: Computed Variables
    
    public var httpStatusCode: Int
    {
        return httpResponse?.statusCode ?? 0
    }
}
