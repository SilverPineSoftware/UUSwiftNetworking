//
//  UUHttpResponseHandler.swift
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

fileprivate let LOG_TAG = "UUBaseResponseHandler"

public protocol UUHttpResponseHandler
{
    func handleResponse(request: UUHttpRequest, data: Data?, response: URLResponse?, error: Error?, completion: @escaping (UUHttpResponse)->())
    
    var successParser: UUHttpDataParser { get }
    var errorParser: UUHttpDataParser { get }
}

open class UUBaseResponseHandler: UUHttpResponseHandler
{
    public required init()
    {
        
    }
    
    open var successParser: UUHttpDataParser
    {
        return UUMimeTypeDataParser()
    }
    
    open var errorParser: UUHttpDataParser
    {
        return UUMimeTypeDataParser()
    }
    
    open func handleResponse(request: UUHttpRequest, data: Data?, response: URLResponse?, error: Error?, completion: @escaping (UUHttpResponse)->())
    {
        if let e = error
        {
            UULog.debug(tag: LOG_TAG, message: "Got an error: \(String(describing: error))")
            let err = UUErrorFactory.wrapNetworkError(e, request)
            finishHandleResponse(request: request, response: response, data: data, result: err, completion: completion)
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else
        {
            let err = UUErrorFactory.createError(UUHttpSessionError.unkownError, [:])
            finishHandleResponse(request: request, response: response, data: data, result: err, completion: completion)
            return
        }
        
        UULog.debug(tag: LOG_TAG, message: "HTTP Response Code: \(httpResponse.statusCode)")
        
        httpResponse.allHeaderFields.forEach()
        { (key: AnyHashable, value: Any) in
            UULog.debug(tag: LOG_TAG, message: "ResponseHeader: \(key) - \(value)")
        }
        
        // Verify there is response data to parse, if not, just finish the operation
        guard let data = data,
              !data.isEmpty,
              let httpResponse = response as? HTTPURLResponse,
              let urlRequest = request.httpRequest else
          {
              finishHandleResponse(request: request, response: response, data: data, result: nil, completion: completion)
              return
          }
        
        UULog.debug(tag: LOG_TAG, message: "ResponseBody: \(String(describing: String(bytes: data, encoding: .utf8)))")
        
        let parser = httpResponse.statusCode.uuIsHttpSuccess() ? successParser : errorParser
        
        parser.parse(data: data, response: httpResponse, request: urlRequest)
        { parseResult in
            
            self.finishHandleResponse(request: request, response: httpResponse, data: data, result: parseResult, completion: completion)
        }
    }
    
    private func finishHandleResponse(request: UUHttpRequest, response: URLResponse?, data: Data?, result: Any?, completion: @escaping (UUHttpResponse)->())
    {
        var err: Error? = nil
        var parsedResponse: Any? = result
        
        if let parseError = result as? Error
        {
            err = parseError
            parsedResponse = nil
        }
        
        let httpResponse = (response as? HTTPURLResponse)
        let httpStatusCode = httpResponse?.statusCode ?? 0
         
        // By default, the standard response parsers won't emit an Error, but custom response handlers might.
        // When callers parse response JSON and return Errors, we will honor that.
        if (err == nil && !isHttpSuccessResponseCode(httpStatusCode))
        {
            err = UUErrorFactory.createHttpError(request, httpStatusCode, parsedResponse)
        }
        
        let uuResponse = UUHttpResponse(request: request, response: httpResponse, error: err, rawResponse: data, parsedResponse: parsedResponse)
        completion(uuResponse)
    }
    
    private func isHttpSuccessResponseCode(_ responseCode : Int) -> Bool
    {
        return (responseCode >= 200 && responseCode < 300)
    }
}

open class UUJsonCodableResponseHandler<SuccessType: Codable, ErrorType: Codable>: UUBaseResponseHandler
{
    public required init()
    {
        super.init()
    }
    
    open override var successParser: UUHttpDataParser
    {
        return UUJsonCodableDataParser<SuccessType>()
    }
    
    open override var errorParser: UUHttpDataParser
    {
        return UUJsonCodableDataParser<ErrorType>()
    }
}

open class UUPassthroughResponseHandler: UUBaseResponseHandler
{
    public required init()
    {
        super.init()
    }
    
    open override var successParser: UUHttpDataParser
    {
        return UUBinaryDataParser()
    }
    
    open override var errorParser: UUHttpDataParser
    {
        return UUBinaryDataParser()
    }
}
