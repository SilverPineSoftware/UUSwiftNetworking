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
	public var httpError : Error? = nil
	public var httpRequest : UUHttpRequest? = nil
	public var httpResponse : HTTPURLResponse? = nil
	public var parsedResponse : Any?
	public var rawResponse : Data? = nil
	public var rawResponsePath : String = ""
	public var downloadTime : TimeInterval = 0

	required init(_ request : UUHttpRequest, _ response : HTTPURLResponse?)
	{
		httpRequest = request
		httpResponse = response
	}
    
    public var httpStatusCode: Int
    {
        return httpResponse?.statusCode ?? 0
    }
}
