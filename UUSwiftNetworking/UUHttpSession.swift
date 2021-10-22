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
    private let urlSession: URLSession
    private let sessionConfiguration: URLSessionConfiguration
    private var activeTasks : [URLSessionTask] = []
    private var activeTasksLock = NSRecursiveLock()
    
    private var responseHandlers : [String:UUHttpResponseHandler] = [:]
    
    public static let shared = UUHttpSession()
    
    public static var defaultConfiguration: URLSessionConfiguration
    {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = UUHttpRequest.defaultTimeout
        cfg.timeoutIntervalForResource = UUHttpRequest.defaultTimeout
        return cfg
    }
    
    required public init(configuration: URLSessionConfiguration = UUHttpSession.defaultConfiguration)
    {
        sessionConfiguration = configuration
        urlSession = URLSession(configuration: sessionConfiguration)
        
        super.init()
        
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
    
    public func executeRequest(_ request : UUHttpRequest, _ completion: @escaping (UUHttpResponse) -> Void) -> UUHttpRequest
    {
        guard let httpRequest = request.buildURLRequest() else
        {
            let uuResponse = UUHttpResponse(request, nil)
            uuResponse.httpError = UUErrorFactory.createInvalidRequestError(request)
            completion(uuResponse)
            return request
        }
        
        request.httpRequest = httpRequest
        
        request.startTime = Date.timeIntervalSinceReferenceDate
        
        /*
        UUDebugLog("Begin Request\n\nMethod: %@\nURL: %@\nHeaders: %@)",
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
        }*/
        
        let task = urlSession.dataTask(with: httpRequest)
        { (data : Data?, response: URLResponse?, error : Error?) in
			
			if let httpTask = request.httpTask
            {
                self.removeActiveTask(httpTask)
			}
            
            self.handleResponse(request, data, response, error, completion)
        }
        
		request.httpTask = task
		
        addActiveTask(task)
        task.resume()
        return request
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
        
        if let error = err
        {
            //UUDebugLog("Got an error: %@", String(describing: error))
            err = UUErrorFactory.wrapNetworkError(error, request)
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
                err = UUErrorFactory.createHttpError(request, uuResponse, parsedResponse)
            }
        }
        
        uuResponse.httpError = err
        uuResponse.parsedResponse = parsedResponse
        uuResponse.downloadTime = Date.timeIntervalSinceReferenceDate - request.startTime
        
        completion(uuResponse)
    }
    
    private func parseResponse(_ request : UUHttpRequest, _ httpResponse : HTTPURLResponse?, _ data : Data?) -> Any?
    {
        guard let httpResponse = httpResponse else
        {
            return nil
        }
        
        guard let data = data, !data.isEmpty else
        {
            return nil
        }

        let httpRequest = request.httpRequest
        
        let mimeType = httpResponse.mimeType
        
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
        
        if let handler = handler,
           let httpRequest = httpRequest
        {
            return handler.parseResponse(data, httpResponse, httpRequest)
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
    
    private func addActiveTask(_ task : URLSessionTask)
    {
        defer { activeTasksLock.unlock() }
        activeTasksLock.lock()
        
        self.activeTasks.append(task)
    }
    
    private func removeActiveTask(_ task : URLSessionTask)
    {
        defer { activeTasksLock.unlock() }
        activeTasksLock.lock()
        
        self.activeTasks.removeAll(where: { $0.taskIdentifier == task.taskIdentifier })
    }
}
