//
//  UUHttpSession.swift
//  Useful Utilities - URLSession wrapper
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//

#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

import UUSwiftCore


@objc
public class UUHttpSession: NSObject
{
    private var urlSession : URLSession? = nil
    private var sessionConfiguration : URLSessionConfiguration? = nil
    private var activeTasks : UUThreadSafeArray<URLSessionTask> = UUThreadSafeArray()
    private var responseHandlers : [String:UUHttpResponseHandler] = [:]
    
    public static let shared = UUHttpSession()
    
    required override public init()
    {
        super.init()
        
        sessionConfiguration = URLSessionConfiguration.default
		sessionConfiguration?.timeoutIntervalForRequest = UUHttpRequest.defaultTimeout
        
        urlSession = URLSession.init(configuration: sessionConfiguration!)
        
        installDefaultResponseHandlers()
    }
    
    private func installDefaultResponseHandlers()
    {
        registerResponseHandler(UUJsonResponseHandler())
        registerResponseHandler(UUTextResponseHandler())
        registerResponseHandler(UUBinaryResponseHandler())
		registerResponseHandler(UUImageResponseHandler())
		registerResponseHandler(UUFormEncodedResponseHandler())
    }
    
    private func registerResponseHandler(_ handler : UUHttpResponseHandler)
    {
        for mimeType in handler.supportedMimeTypes
        {
            responseHandlers[mimeType] = handler
        }
    }
    
    private func executeRequest(_ request : UUHttpRequest, _ completion: @escaping (UUHttpResponse) -> Void) -> UUHttpRequest
    {
        let httpRequest : URLRequest? = buildRequest(request)
        if (httpRequest == nil)
        {
            let uuResponse : UUHttpResponse = UUHttpResponse(request, nil)
            uuResponse.httpError = NSError.init(domain: UUHttpSessionErrorDomain, code: UUHttpSessionError.invalidRequest.rawValue, userInfo: nil)
            completion(uuResponse)
            return request
        }
        
        request.httpRequest = httpRequest!
        
        request.startTime = Date.timeIntervalSinceReferenceDate
        
        /*UUDebugLog("Begin Request\n\nMethod: %@\nURL: %@\nHeaders: %@)",
            String(describing: request.httpRequest?.httpMethod),
            String(describing: request.httpRequest?.url),
            String(describing: request.httpRequest?.allHTTPHeaderFields))
        
        if (request.body != nil)
        {
            if (UUContentType.applicationJson == request.bodyContentType)
            {
                UUDebugLog("JSON Body: %@", request.body!.uuToJsonString())
            }
            else
            {
                if (request.body!.count < 10000)
                {
                    UUDebugLog("Raw Body: %@", request.body!.uuToHexString())
                }
            }
        }
        */
        let task = urlSession!.dataTask(with: request.httpRequest!)
        { (data : Data?, response: URLResponse?, error : Error?) in
			
			if let httpTask = request.httpTask {
				self.activeTasks.remove(httpTask)
			}
            self.handleResponse(request, data, response, error, completion)
        }
		request.httpTask = task
		
        activeTasks.append(task)
        task.resume()
        return request
    }
    
    private func buildRequest(_ request : UUHttpRequest) -> URLRequest?
    {
        var fullUrl = request.url;
        if (request.queryArguments.count > 0)
        {
			let startingURL = request.url
			var queryString = request.queryArguments.uuBuildQueryString()
			if startingURL.contains("?") {
				queryString = queryString.replacingOccurrences(of: "?", with: "&")
			}
            fullUrl = "\(startingURL)\(queryString)"
        }
        
        guard let url = URL.init(string: fullUrl) else
        {
            return nil
        }
        
        var req : URLRequest = URLRequest(url: url)
        req.httpMethod = request.httpMethod.rawValue
        req.timeoutInterval = request.timeout
		req.cachePolicy = request.cachePolicy
        
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
    
    private func handleResponse(
        _ request : UUHttpRequest,
        _ data : Data?,
        _ response : URLResponse?,
        _ error : Error?,
        _ completion: @escaping (UUHttpResponse) -> Void)
    {
        let httpResponse : HTTPURLResponse? = response as? HTTPURLResponse
        
        let uuResponse : UUHttpResponse = UUHttpResponse(request, httpResponse)
        uuResponse.rawResponse = data
        
        var err : Error? = error
        var parsedResponse : Any? = nil
        
        var httpResponseCode : Int = 0
        
        if (httpResponse != nil)
        {
            httpResponseCode = httpResponse!.statusCode
        }
        
		/*
        UUDebugLog("Http Response Code: %d", httpResponseCode)
        
        if let responseHeaders = httpResponse?.allHeaderFields
        {
            UUDebugLog("Response Headers: %@", responseHeaders)
        }
		*/
        
        if (error != nil)
        {
            UUDebugLog("Got an error: %@", String(describing: error!))
        }
        else
        {
            if (request.processMimeTypes)
            {
                parsedResponse = parseResponse(request, httpResponse, data)
                if (parsedResponse is Error)
                {
                    err = (parsedResponse as! Error)
                    parsedResponse = nil
                }
            }
            
            // By default, the standard response parsers won't emit an Error, but custom response handlers might.
            // When callers parse response JSON and return Errors, we will honor that.
            if (err == nil && !isHttpSuccessResponseCode(httpResponseCode))
            {
                var d : [String:Any] = [:]
                d[UUHttpSessionHttpErrorCodeKey] = NSNumber(value: httpResponseCode)
                d[UUHttpSessionHttpErrorMessageKey] = HTTPURLResponse.localizedString(forStatusCode: httpResponseCode)
                d[UUHttpSessionAppResponseKey] = parsedResponse
                d[NSLocalizedDescriptionKey] = HTTPURLResponse.localizedString(forStatusCode: httpResponseCode)

                err = NSError.init(domain:UUHttpSessionErrorDomain, code:UUHttpSessionError.httpError.rawValue, userInfo:d)
            }
        }
        
        uuResponse.httpError = err;
        uuResponse.parsedResponse = parsedResponse;
        uuResponse.downloadTime = Date.timeIntervalSinceReferenceDate - request.startTime
        
        completion(uuResponse)
    }
    
    private func parseResponse(_ request : UUHttpRequest, _ httpResponse : HTTPURLResponse?, _ data : Data?) -> Any?
    {
        if (httpResponse != nil)
        {
            let httpRequest = request.httpRequest
            
            let mimeType = httpResponse!.mimeType
            
            /*UUDebugLog("Parsing response,\n%@ %@", String(describing: httpRequest?.httpMethod), String(describing: httpRequest?.url))
            UUDebugLog("Response Mime: %@", String(describing: mimeType))
            
            if let responseData = data
            {
                let logLimit = 10000
                var responseStr : String? = nil
                if (responseData.count > logLimit)
                {
                    responseStr = String(data: responseData.subdata(in: 0..<logLimit), encoding: .utf8)
                }
                else
                {
                    responseStr = String(data: responseData, encoding: .utf8)
                }
                
                //UUDebugLog("Raw Response: %@", String(describing: responseStr))
            }
            */
            var handler = request.responseHandler
            
            if (handler == nil && mimeType != nil)
            {
                handler = responseHandlers[mimeType!]
            }
            
            if (handler != nil && data != nil && httpRequest != nil)
            {
                let parsedResponse = handler!.parseResponse(data!, httpResponse!, httpRequest!)
                return parsedResponse
            }
        }
        
        return nil
    }
    
    private func isHttpSuccessResponseCode(_ responseCode : Int) -> Bool
    {
        return (responseCode >= 200 && responseCode < 300)
    }
    
    public static func executeRequest(_ request : UUHttpRequest, _ completion: @escaping (UUHttpResponse) -> Void) -> UUHttpRequest
    {
        return shared.executeRequest(request, completion)
    }
    
    public static func get(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], completion: @escaping (UUHttpResponse) -> Void)
    {
        let req = UUHttpRequest(url: url, method: .get, queryArguments: queryArguments)
        _ = executeRequest(req, completion)
    }
    
    public static func delete(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], completion: @escaping (UUHttpResponse) -> Void)
    {
        let req = UUHttpRequest(url: url, method: .delete, queryArguments: queryArguments)
        _ = executeRequest(req, completion)
    }
    
    public static func put(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], body: Data?, contentType : String?, completion: @escaping (UUHttpResponse) -> Void)
    {
        let req = UUHttpRequest(url: url, method: .put, queryArguments: queryArguments, body: body, contentType: contentType)
        _ = executeRequest(req, completion)
    }
    
    public static func post(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], body: Data?, contentType : String?, completion: @escaping (UUHttpResponse) -> Void)
    {
        let req = UUHttpRequest(url: url, method: .post, queryArguments: queryArguments, body: body, contentType: contentType)
        _ = executeRequest(req, completion)
    }
    
    public static func registerResponseHandler(_ handler : UUHttpResponseHandler)
    {
        shared.registerResponseHandler(handler)
    }
}
