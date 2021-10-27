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
    
    public func executeRequest(_ request : UUHttpRequest, _ completion: @escaping (UUHttpResponse) -> ()) -> UUHttpRequest
    {
        guard let httpRequest = request.buildURLRequest() else
        {
            let uuResponse = UUHttpResponse(request: request, response: nil, error: UUErrorFactory.createInvalidRequestError(request))
            completion(uuResponse)
            return request
        }
        
        request.httpRequest = httpRequest
        
        request.startTime = Date.timeIntervalSinceReferenceDate
        
        /*
        NSLog("Begin Request\n\nMethod: %@\nURL: %@\nHeaders: %@)",
            String(describing: request.httpRequest?.httpMethod),
            String(describing: request.httpRequest?.url),
            String(describing: request.httpRequest?.allHTTPHeaderFields))
        
        if (request.body != nil)
        {
            if (UUContentType.applicationJson == request.bodyContentType)
            {
                NSLog("JSON Body: %@", request.body!.uuToJsonString())
            }
            else
            {
                if (request.body!.count < 10000)
                {
                    NSLog("Raw Body: %@", request.body!.uuToHexString())
                }
            }
        }*/
        
        let task = urlSession.dataTask(with: httpRequest)
        { (data : Data?, response: URLResponse?, error : Error?) in
			
			if let httpTask = request.httpTask
            {
                self.removeActiveTask(httpTask)
			}
            
            request.handleResponse(data: data, response: response, error: error, completion: completion)
        }
        
		request.httpTask = task
		
        addActiveTask(task)
        task.resume()
        return request
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

// MARK: Codable Convenience Methods
extension UUHttpSession
{
    public func executeCodableRequest<T: Codable>(_ request: UUHttpRequest, _ completion: @escaping (T?, Error?) -> ()) -> UUHttpRequest
    {
        request.responseHandler = UUJsonCodableResponseHandler<T>()
        return executeRequest(request)
        { response in
            completion(response.parsedResponse as? T, response.httpError)
        }
    }
    
}

// MARK: Static Convenience Methods
extension UUHttpSession
{
    public static func executeRequest(_ request : UUHttpRequest, _ completion: @escaping (UUHttpResponse) -> Void) -> UUHttpRequest
    {
        return shared.executeRequest(request, completion)
    }
    
    public static func get(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], completion: @escaping (UUHttpResponse) -> Void)
    {
        let req = UUHttpRequest(url: url, method: .get, queryArguments: queryArguments, headers: headers)
        _ = executeRequest(req, completion)
    }
    
    public static func delete(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], completion: @escaping (UUHttpResponse) -> Void)
    {
        let req = UUHttpRequest(url: url, method: .delete, queryArguments: queryArguments, headers: headers)
        _ = executeRequest(req, completion)
    }
    
    public static func put(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], body: Data?, contentType : String?, completion: @escaping (UUHttpResponse) -> Void)
    {
        let req = UUHttpRequest(url: url, method: .put, queryArguments: queryArguments, headers: headers, body: body, contentType: contentType)
        _ = executeRequest(req, completion)
    }
    
    public static func post(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], body: Data?, contentType : String?, completion: @escaping (UUHttpResponse) -> Void)
    {
        let req = UUHttpRequest(url: url, method: .post, queryArguments: queryArguments, headers: headers, body: body, contentType: contentType)
        _ = executeRequest(req, completion)
    }
}

// MARK: Static Codable Convenience Methods
extension UUHttpSession
{
    public static func get<T: Codable>(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], completion: @escaping (T?, Error?) -> ())
    {
        let req = UUHttpRequest(url: url, method: .get, queryArguments: queryArguments, headers: headers)
        executeCodableRequest(req, completion)
    }
    
    public static func executeCodableRequest<T: Codable>(_ request: UUHttpRequest, _ completion: @escaping (T?, Error?) -> ())
    {
        _ = shared.executeCodableRequest(request, completion)
    }
}
