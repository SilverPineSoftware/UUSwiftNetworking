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
    
	private(set) public var httpError: Error? = nil
	private(set) public var parsedResponse: Any?
    private(set) public var rawResponse: Data? = nil
    //private(set) public var rawResponsePath: String = ""
    private(set) public var endTime: TimeInterval = 0

    required init(request : UUHttpRequest, response: HTTPURLResponse?, error: Error?)
	{
		httpRequest = request
		httpResponse = response
        httpError = error
	}
    
    // MARK: Internal Setters
    
    func set(error: Error?)
    {
        self.httpError = error
    }
    
    func set(rawResponse: Data?)
    {
        self.rawResponse = rawResponse
    }
    
    func set(parsedResponse: Any?)
    {
        self.parsedResponse = parsedResponse
    }
    
    func set(endTime: TimeInterval)
    {
        self.endTime = endTime
    }
    
    // MARK: Computed Variables
    
    public var httpStatusCode: Int
    {
        return httpResponse?.statusCode ?? 0
    }
}
