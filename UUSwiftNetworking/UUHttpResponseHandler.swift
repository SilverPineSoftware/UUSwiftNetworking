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

public protocol UUHttpResponseHandler
{
    func handleResponse(request: UUHttpRequest, data: Data?, response: URLResponse?, error: Error?, completion: @escaping (UUHttpResponse)->())
    
    var dataParser: UUHttpDataParser { get }
}

open class UUBaseResponseHandler: UUHttpResponseHandler
{
    public required init()
    {
        
    }
    
    open var dataParser: UUHttpDataParser
    {
        return UUMimeTypeDataParser()
    }
    
    open func handleResponse(request: UUHttpRequest, data: Data?, response: URLResponse?, error: Error?, completion: @escaping (UUHttpResponse)->())
    {
//        NSLog("Http Response Code: %d", httpResponseCode)
//
//        if let responseHeaders = httpResponse?.allHeaderFields
//        {
//            NSLog("Response Headers: %@", responseHeaders)
//        }
        
        if let e = error
        {
            //UUDebugLog("Got an error: %@", String(describing: error))
            let err = UUErrorFactory.wrapNetworkError(e, request)
            finishHandleResponse(request: request, response: response, data: data, result: err, completion: completion)
            return
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
        
        dataParser.parse(data: data, response: httpResponse, request: urlRequest)
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

open class UUJsonCodableResponseHandler<T: Codable>: UUBaseResponseHandler
{
    public required init()
    {
        super.init()
    }
    
    open override var dataParser: UUHttpDataParser
    {
        return UUJsonCodableDataParser<T>()
    }
}

open class UUPassthroughResponseHandler: UUBaseResponseHandler
{
    public required init()
    {
        super.init()
    }
    
    open override var dataParser: UUHttpDataParser
    {
        return UUBinaryDataParser()
    }
}
