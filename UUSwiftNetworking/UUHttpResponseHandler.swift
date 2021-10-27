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
        let httpResponse : HTTPURLResponse? = response as? HTTPURLResponse
        
        let uuResponse : UUHttpResponse = UUHttpResponse(request, httpResponse)
        uuResponse.rawResponse = data
        
        var err : Error? = error
        //var parsedResponse : Any? = nil
        
        let httpResponseCode = uuResponse.httpStatusCode

        NSLog("Http Response Code: %d", httpResponseCode)
        
        if let responseHeaders = httpResponse?.allHeaderFields
        {
            NSLog("Response Headers: %@", responseHeaders)
        }
        
        if let error = err
        {
            //UUDebugLog("Got an error: %@", String(describing: error))
            err = UUErrorFactory.wrapNetworkError(error, request)
            finishHandleResponse(request: request, response: uuResponse, result: err, completion: completion)
            return
        }
        
        // Verify there is response data to parse, if not, just finish the operation
        guard let data = data,
              !data.isEmpty,
              let httpResponse = httpResponse,
              let urlRequest = request.httpRequest else
          {
              finishHandleResponse(request: request, response: uuResponse, result: nil, completion: completion)
              return
          }
        
        
        dataParser.parse(data: data, response: httpResponse, request: urlRequest)
        { parseResult in
            
            self.finishHandleResponse(request: request, response: uuResponse, result: parseResult, completion: completion)
        }
    }
    
    private func finishHandleResponse(request: UUHttpRequest, response: UUHttpResponse, result: Any?, completion: @escaping (UUHttpResponse)->())
    {
        var err: Error? = nil
        var parsedResponse: Any? = result
        
        if let parseError = result as? Error
        {
            err = parseError
            parsedResponse = nil
        }
         
        // By default, the standard response parsers won't emit an Error, but custom response handlers might.
        // When callers parse response JSON and return Errors, we will honor that.
        if (err == nil && !isHttpSuccessResponseCode(response.httpStatusCode))
        {
            err = UUErrorFactory.createHttpError(request, response, parsedResponse)
        }
        
        response.httpError = err
        response.parsedResponse = parsedResponse
        response.downloadTime = Date.timeIntervalSinceReferenceDate - (response.httpRequest?.startTime ?? 0)
        
        completion(response)
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
