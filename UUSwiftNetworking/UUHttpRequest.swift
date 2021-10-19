//
//  UUHttpRequest.swift
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


public class UUHttpRequest: NSObject
{
	public static var defaultTimeout : TimeInterval = 60.0
	public static var defaultCachePolicy : URLRequest.CachePolicy = .useProtocolCachePolicy

	public var url : String = ""
	public var httpMethod : UUHttpMethod = .get
	public var queryArguments : UUQueryStringArgs = [:]
	public var headerFields : UUHttpHeaders = [:]
	public var body : Data? = nil
	public var bodyContentType : String? = nil
	public var timeout : TimeInterval = UUHttpRequest.defaultTimeout
	public var cachePolicy : URLRequest.CachePolicy = UUHttpRequest.defaultCachePolicy
	public var credentials : URLCredential? = nil
	public var processMimeTypes : Bool = true
	public var startTime : TimeInterval = 0
	public var httpRequest : URLRequest? = nil
	public var httpTask : URLSessionTask? = nil
	public var responseHandler : UUHttpResponseHandler? = nil
	public var form : UUHttpForm? = nil

	public init(url : String, method: UUHttpMethod = .get, queryArguments: UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], body : Data? = nil, contentType : String? = nil)
	{
		super.init()

		self.url = url
		self.httpMethod = method
		self.queryArguments = queryArguments
		self.headerFields = headers
		self.body = body
		self.bodyContentType = contentType
	}

	public convenience init(url : String, method: UUHttpMethod = .post, queryArguments: UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], form : UUHttpForm)
	{
		self.init(url: url, method: method, queryArguments: queryArguments, headers: headers, body: nil, contentType: nil)
		self.form = form
	}

	public func cancel() {
		self.httpTask?.cancel()
	}
}
