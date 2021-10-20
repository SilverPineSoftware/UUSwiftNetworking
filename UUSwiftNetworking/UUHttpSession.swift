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
    private var activeTasks : [URLSessionTask] = []
    private var activeTasksLock = NSRecursiveLock()
    

    public static let shared = UUHttpSession()
    
    required override public init()
    {
        super.init()
        
        sessionConfiguration = URLSessionConfiguration.default
		sessionConfiguration?.timeoutIntervalForRequest = UUHttpRequest.defaultTimeout
        
        urlSession = URLSession.init(configuration: sessionConfiguration!)
    }


    private func executeRequest(_ request : UUHttpRequest, _ completion: @escaping (UUHttpResponse) -> Void) -> UUHttpRequest
    {
        guard let httpRequest = buildRequest(request) else
        {
			let uuResponse = UUHttpResponse(request: request, response: nil, data: nil, error: UUErrorFactory.createInvalidRequestError(request), elapsedTime: 0.0)
            completion(uuResponse)
            return request
        }
        
        request.httpRequest = httpRequest
        request.startTime = Date.timeIntervalSinceReferenceDate

        let task = urlSession!.dataTask(with: request.httpRequest!)
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

		var err : Error? = error
        if let error = err
        {
            UUDebugLog("Got an error: %@", String(describing: error))
            err = UUErrorFactory.wrapNetworkError(error, request)
        }

		let uuResponse = UUHttpResponse(request: request, response: httpResponse, data: data, error: err, elapsedTime: Date.timeIntervalSinceReferenceDate - request.startTime)
        completion(uuResponse)
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
