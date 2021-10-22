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
    }


    public func executeRequest(_ request : UUHttpRequest, _ completion: @escaping (UUHttpResponse) -> Void) -> UUHttpRequest
    {
        guard let httpRequest = request.buildURLRequest() else
        {
			let uuResponse = UUHttpResponse(request: request, response: nil, data: nil, error: UUErrorFactory.createInvalidRequestError(request))
            completion(uuResponse)
            return request
        }
        
        request.httpRequest = httpRequest

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

        var err : Error? = error
        if let error = err
        {
            //UUDebugLog("Got an error: %@", String(describing: error))
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
