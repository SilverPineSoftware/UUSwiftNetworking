//
//  UUHttpSession.swift
//  Useful Utilities - URLSession wrapper
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUHttpSession"

public class UUHttpSession: NSObject, @unchecked Sendable
{
    private let urlSession: URLSession
    private let sessionConfiguration: URLSessionConfiguration

    nonisolated(unsafe) public static let shared = UUHttpSession()
    
    public static var defaultConfiguration: URLSessionConfiguration
    {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = UUHttpConfig.shared.defaultTimeout
        cfg.timeoutIntervalForResource = UUHttpConfig.shared.defaultTimeout
        return cfg
    }
    
    required public init(
        configuration: URLSessionConfiguration = UUHttpSession.defaultConfiguration,
        delegate: URLSessionDelegate? = nil)
    {
        sessionConfiguration = configuration
        
        urlSession = URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
        
        super.init()
    }
    
    /*
    public func executeRequest(_ request : UUHttpRequest, _ completion: @escaping (UUHttpResponse) -> ()) -> UUHttpRequest
    {
        guard var httpRequest = request.buildURLRequest() else
        {
            let uuResponse = UUHttpResponse(request: request, response: nil, error: UUErrorFactory.createInvalidRequestError(request))
            completion(uuResponse)
            return request
        }
        
        httpRequest.uuApplyAdditionalHeaders(from: sessionConfiguration)
        
        request.httpRequest = httpRequest
        
        request.startTime = Date.timeIntervalSinceReferenceDate
        
        
        UULog.debug(tag: LOG_TAG, message: "Begin Request\n\nMethod: \(String(describing: request.httpRequest?.httpMethod))\nURL: \(String(describing: request.httpRequest?.url))\nHeaders: \(String(describing: request.httpRequest?.allHTTPHeaderFields))")
        
        if (request.body != nil)
        {
            if (UUContentType.applicationJson == request.bodyContentType)
            {
                UULog.debug(tag: LOG_TAG, message: "JSON Body: \(request.body!.uuToJsonString())")
            }
            else
            {
                if (request.body!.count < 10000)
                {
                    UULog.debug(tag: LOG_TAG, message: "Raw Body: \(request.body!.uuToHexString())")
                }
            }
        }
        
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
    }*/
    
    public func executeRequest(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        guard var httpRequest = await request.buildURLRequest() else
        {
            return UUHttpResponse(request: request, response: nil, error: UUErrorFactory.createInvalidRequestError(request))
        }
        
        httpRequest.uuApplyAdditionalHeaders(from: sessionConfiguration)
        
        request.httpRequest = httpRequest
        
        request.startTime = Date.timeIntervalSinceReferenceDate
        
        UULog.debug(tag: LOG_TAG, message: "Begin Request\n\nMethod: \(String(describing: request.httpRequest?.httpMethod))\nURL: \(String(describing: request.httpRequest?.url))\nHeaders: \(String(describing: request.httpRequest?.allHTTPHeaderFields))")
        
        if (request.body != nil)
        {
            if (UUContentType.applicationJson == request.bodyContentType)
            {
                UULog.debug(tag: LOG_TAG, message: "JSON Body: \(request.body!.uuToJsonString())")
            }
            else
            {
                if (request.body!.count < 10000)
                {
                    UULog.debug(tag: LOG_TAG, message: "Raw Body: \(request.body!.uuToHexString())")
                }
            }
        }
        
        if Task.isCancelled
        {
            return await userCancelledResponse(for: request)
        }
        
        return await performDataRequest(request, httpRequest: httpRequest)
    }
    
    private func performDataRequest(_ request: UUHttpRequest, httpRequest: URLRequest) async -> UUHttpResponse
    {
        do
        {
            let (data, urlResponse) = try await urlSession.data(for: httpRequest)
            return await request.handleResponse(data: data, response: urlResponse, error: nil)
        }
        catch is CancellationError
        {
            return await userCancelledResponse(for: request)
        }
        catch
        {
            return await request.handleResponse(data: nil, response: nil, error: error)
        }
    }
    
    private func userCancelledResponse(for request: UUHttpRequest) async -> UUHttpResponse
    {
        return await request.handleResponse(
            data: nil,
            response: nil,
            error: UUErrorFactory.createError(.userCancelled, nil))
    }
    
    public func cancelAll()
    {
        urlSession.getAllTasks
        { tasks in
            tasks.forEach { $0.cancel() }
        }
    }
}

// MARK: Codable Convenience Methods
public extension UUHttpSession
{
    func executeCodableRequest<SuccessType: Codable, ErrorType: Codable>(
        _ request: UUCodableHttpRequest<SuccessType, ErrorType>) async -> Result<SuccessType, Error>
    {
        let result = await executeRequest(request)
        
        if let err = result.httpError
        {
            return .failure(err)
        }
        else if let success = result.parsedResponse as? SuccessType
        {
            return .success(success)
        }
        else
        {
            // TODO: Is this the correct error
            return .failure(UUErrorFactory.createError(.parseFailure, nil))
        }
    }
}

// MARK: Static Convenience Methods
extension UUHttpSession
{
    public static func executeRequest(_ request : UUHttpRequest) async -> UUHttpResponse
    {
        return await shared.executeRequest(request)
    }
    
    public static func get(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:]) async -> UUHttpResponse
    {
        let req = UUHttpRequest(url: url, method: .get, queryArguments: queryArguments, headers: headers)
        return await executeRequest(req)
    }
    
    public static func delete(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:]) async -> UUHttpResponse
    {
        let req = UUHttpRequest(url: url, method: .delete, queryArguments: queryArguments, headers: headers)
        return await executeRequest(req)
    }
    
    public static func put(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], body: Data?, contentType : String?) async -> UUHttpResponse
    {
        let req = UUHttpRequest(url: url, method: .put, queryArguments: queryArguments, headers: headers, body: body, contentType: contentType)
        return await executeRequest(req)
    }
    
    public static func post(url : String, queryArguments : UUQueryStringArgs = [:], headers: UUHttpHeaders = [:], body: Data?, contentType : String?) async -> UUHttpResponse
    {
        let req = UUHttpRequest(url: url, method: .post, queryArguments: queryArguments, headers: headers, body: body, contentType: contentType)
        return await executeRequest(req)
    }
}

// MARK: Static Codable Convenience Methods
public extension UUHttpSession
{
    static func executeCodableRequest<SuccessType: Codable, ErrorType: Codable>(
        _ request: UUCodableHttpRequest<SuccessType, ErrorType>) async -> Result<SuccessType, Error>
    {
        return await shared.executeCodableRequest(request)
    }
}
