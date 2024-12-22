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

fileprivate let LOG_TAG = "UUHttpRequest"

import UUSwiftCore

open class UUHttpRequest: NSObject
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
	//public var processMimeTypes : Bool = true
	public var startTime : TimeInterval = 0
	public var httpRequest : URLRequest? = nil
	public var httpTask : URLSessionTask? = nil
	public var responseHandler : UUHttpResponseHandler = UUBaseResponseHandler()
	public var form : UUHttpForm? = nil
    public var authorizationProvider: UUHttpAuthorizationProvider? = nil
    
    //public var credentials : URLCredential? = nil

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

	public func cancel()
    {
		self.httpTask?.cancel()
	}
    
    func buildURLRequest() -> URLRequest?
    {
        let request = self
        
        var fullUrl = request.url
        
        if (request.queryArguments.count > 0)
        {
            let startingURL = request.url
            var queryString = request.queryArguments.uuBuildQueryString()
            if startingURL.contains("?")
            {
                queryString = queryString.replacingOccurrences(of: "?", with: "&")
            }
            
            fullUrl = "\(startingURL)\(queryString)"
        }
        
        guard let url = URL.init(string: fullUrl) else
        {
            UULog.verbose(tag: LOG_TAG, message: "Invalid URL: \(fullUrl)")
            return nil
        }
        
        guard url.scheme != nil else
        {
            UULog.verbose(tag: LOG_TAG, message: "URL scheme is nil: \(fullUrl)")
            return nil
        }
        
        guard url.host != nil else
        {
            UULog.verbose(tag: LOG_TAG, message: "URL host is nil: \(fullUrl)")
            return nil
        }
        
        var req : URLRequest = URLRequest(url: url)
        req.httpMethod = request.httpMethod.rawValue
        req.timeoutInterval = request.timeout
        req.cachePolicy = request.cachePolicy
        
        self.authorizationProvider?.attachAuthorization(to: self)
        
        for key in request.headerFields.keys
        {
            let strKey = (key as? String) ?? String(describing: key)
            
            if let val = request.headerFields[key]
            {
                let strVal = (val as? String) ?? String(describing: val)
                req.addValue(strVal, forHTTPHeaderField: strKey)
            }
        }
        
        if let form = request.form
        {
            request.body = form.formData()
            request.bodyContentType = form.formContentType()
        }
        
        if (request.body != nil)
        {
            req.setValue(String.init(format: "%lu", request.body!.count), forHTTPHeaderField: UUHeader.contentLength)
            req.httpBody = request.body
            
            if (request.bodyContentType != nil && request.bodyContentType!.count > 0)
            {
                req.addValue(request.bodyContentType!, forHTTPHeaderField: UUHeader.contentType)
            }
        }
        
        return req
    }
    
    func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (UUHttpResponse)->())
    {
        responseHandler.handleResponse(request: self, data: data, response: response, error: error, completion: completion)
    }
}


open class UUCodableHttpRequest<SuccessType: Codable, ErrorType: Codable>: UUHttpRequest
{
    public var successHandler: UUHttpDataParser = UUJsonCodableDataParser<SuccessType>()
    public var errorHandler: UUHttpDataParser = UUJsonCodableDataParser<ErrorType>()
    
    public override init(url: String, method: UUHttpMethod = .get, queryArguments: UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], body: Data? = nil, contentType: String? = nil)
    {
        super.init(url: url, method: method, queryArguments: queryArguments, headers: headers, body: body, contentType: contentType)
        
        responseHandler = UUJsonCodableResponseHandler<SuccessType, ErrorType>()
    }
    
}
