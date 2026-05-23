//
//  UUBaseResponseHandler.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUBaseResponseHandler"

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
    
    open func handleResponse(request: UUHttpRequest, data: Data?, response: URLResponse?, error: Error?) async -> UUHttpResponse
    {
        if let e = error
        {
            UULog.debug(tag: LOG_TAG, message: "Got an error: \(String(describing: error))")
            let err = UUErrorFactory.wrapNetworkError(e, request)
            return await finishHandleResponse(request: request, response: response, data: data, result: err)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else
        {
            let err = UUErrorFactory.createError(UUHttpSessionError.unkownError, [:])
            return await finishHandleResponse(request: request, response: response, data: data, result: err)
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
              return await finishHandleResponse(request: request, response: response, data: data, result: nil)
          }
        
        UULog.debug(tag: LOG_TAG, message: "ResponseBody: \(String(describing: String(bytes: data, encoding: .utf8)))")
        
        let parser = httpResponse.statusCode.uuIsHttpSuccess() ? successParser : errorParser
        
        let parseResult = await parser.parse(data: data, response: httpResponse, request: urlRequest)
        return await finishHandleResponse(request: request, response: httpResponse, data: data, result: parseResult)
    }
    
    private func finishHandleResponse(request: UUHttpRequest, response: URLResponse?, data: Data?, result: Any?) async -> UUHttpResponse
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
        return uuResponse
    }
    
    private func isHttpSuccessResponseCode(_ responseCode : Int) -> Bool
    {
        return (responseCode >= 200 && responseCode < 300)
    }
}
