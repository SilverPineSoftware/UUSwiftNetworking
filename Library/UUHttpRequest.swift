//
//  UUHttpRequest.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUHttpRequest"

open class UUHttpRequest: NSObject, @unchecked Sendable
{
	public var url : String = ""
	public var httpMethod : UUHttpMethod = .get
	public var queryArguments : UUQueryStringArgs = [:]
	public var headerFields : UUHttpHeaders = [:]
//	public var body : Data? = nil
//	public var bodyContentType : String? = nil
    public var body: UUHttpBody? = nil
    public var timeout : TimeInterval = UUHttpConfig.shared.defaultTimeout
    public var cachePolicy : URLRequest.CachePolicy = UUHttpConfig.shared.defaultCachePolicy
	public var startTime : TimeInterval = 0
	public var httpRequest : URLRequest? = nil
	public var responseHandler : UUHttpResponseHandler = UUBaseResponseHandler()
	//public var form : UUHttpForm? = nil
    public var authorizationProvider: UUHttpAuthorizationProvider? = nil
    
	public init(url : String, method: UUHttpMethod = .get, queryArguments: UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], body : UUHttpBody? = nil)
	{
		super.init()

		self.url = url
		self.httpMethod = method
		self.queryArguments = queryArguments
		self.headerFields = headers
		self.body = body
	}

//	public convenience init(url : String, method: UUHttpMethod = .post, queryArguments: UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], form : UUHttpForm)
//	{
//		self.init(url: url, method: method, queryArguments: queryArguments, headers: headers, body: nil)
//		self.form = form
//	}

    func buildURLRequest() async -> URLRequest?
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
        
        await self.authorizationProvider?.attachAuthorization(self)
        
        for key in request.headerFields.keys
        {
            let strKey = (key as? String) ?? String(describing: key)
            
            if let val = request.headerFields[key]
            {
                let strVal = (val as? String) ?? String(describing: val)
                req.addValue(strVal, forHTTPHeaderField: strKey)
            }
        }
        
        /*
        if let form = request.form
        {
            request.body = form.formData()
            request.bodyContentType = form.formContentType()
        }
        
        if (request.body != nil)
        {
            req.setValue(String.init(format: "%lu", request.body!.count), forHTTPHeaderField: UUHttpHeader.contentLength)
            req.httpBody = request.body
            
            if (request.bodyContentType != nil && request.bodyContentType!.count > 0)
            {
                req.addValue(request.bodyContentType!, forHTTPHeaderField: UUHttpHeader.contentType)
            }
        }*/
        
        
        
//        val preparedBody = request.body?.prepareToSend()?.getOrElse()
//                    { error ->
//                        UUHttpLogging.logError(request, error)
//                        return UUHttpResponse(request = request, error = error)
//                    }
        
        //if let body = request
        
        
        /*
        changeState(request, UUHttpRequest.State.PrepareToSend)
                    val preparedBody = request.body?.prepareToSend()?.getOrElse()
                    { error ->
                        UUHttpLogging.logError(request, error)
                        return UUHttpResponse(request = request, error = error)
                    }

                    preparedBody?.second?.entries?.forEach()
                    { entry ->
                        request.headers[entry.key] = entry.value
                    }

                    UUHttpLogging.logHeaders(request, UUHttpLoggingMode.RequestHeaders, request.headers)
*/
        
        return req
    }
    
    func handleResponse(data: Data?, response: URLResponse?, error: Error?) async -> UUHttpResponse
    {
        return await responseHandler.handleResponse(request: self, data: data, response: response, error: error)
    }
}

public extension URLRequest
{
    mutating func uuApplyHeaders(_ headers: UUHttpHeaders)
    {
        for (key, value) in headers
        {
            if let keyString = key as? String, let valueString = value as? String
            {
                setValue(valueString, forHTTPHeaderField: keyString)
            }
        }
    }
    
    mutating func uuApplyAdditionalHeaders(from configuration: URLSessionConfiguration)
    {
        if let headers = configuration.httpAdditionalHeaders
        {
            for (key, value) in headers
            {
                if let keyString = key as? String, let valueString = value as? String
                {
                    setValue(valueString, forHTTPHeaderField: keyString)
                }
            }
        }
    }
}


open class UUCodableHttpRequest<SuccessType: Codable, ErrorType: Codable>: UUHttpRequest, @unchecked Sendable
{
    public var successHandler: UUHttpDataParser = UUJsonCodableDataParser<SuccessType>()
    public var errorHandler: UUHttpDataParser = UUJsonCodableDataParser<ErrorType>()
    
    public override init(
        url: String,
        method: UUHttpMethod = .get,
        queryArguments: UUQueryStringArgs = [:],
        headers: UUHttpHeaders = [:],
        body: UUHttpBody? = nil)
    {
        super.init(url: url, method: method, queryArguments: queryArguments, headers: headers, body: body)
        
        responseHandler = UUJsonCodableResponseHandler<SuccessType, ErrorType>()
    }
    
}
