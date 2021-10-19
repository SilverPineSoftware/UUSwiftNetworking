//
//  UUHttpError.swift
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

public enum UUHttpSessionError : Int
{
	// Returned when URLSession returns a non-nil error and the underlying
	// error domain is NSURLErrorDomain and the underlying error code is
	// NSURLErrorNotConnectedToInternet
	case noInternet = 0x1000

	// Returned when URLSession returns a non-nil error and the underlying
	// error domain is NSURLErrorDomain and the underlying error code is
	// NSURLErrorCannotFindHost
	case cannotFindHost = 0x1001

	// Returned when URLSession returns a non-nil error and the underlying
	// error domain is NSURLErrorDomain and the underlying error code is
	// NSURLErrorTimedOut
	case timedOut = 0x1002

	// Returned when URLSession completion block returns a non-nil Error, and
	// that error is not specifically mapped to a more common UUHttpSessionError
	// In this case, the underlying NSError is wrapped in the user info block
	// using the NSUnderlyingError key
	case httpFailure = 0x2000

	// Returned when the URLSession completion block returns with a nil Error
	// and an HTTP return code that is not 2xx
	case httpError = 0x2001

	// Returned when a user cancels an operation
	case userCancelled = 0x2002

	// The request URL and/or query string parameters resulted in an invalid
	// URL.
	case invalidRequest = 0x2003
    
    /**
     UU failed to parse a response.  See underlying error for more details
     */
    case parseFailure = 0x2004
}

public let UUHttpSessionErrorDomain         = "UUHttpSessionErrorDomain"
public let UUHttpSessionHttpErrorCodeKey    = "UUHttpSessionHttpErrorCode"
public let UUHttpSessionHttpErrorMessageKey = "UUHttpSessionHttpErrorMessage"
public let UUHttpSessionAppResponseKey      = "UUHttpSessionAppResponse"
public let UUHttpSessionErrorHttpMethodKey      = "UUHttpSessionErrorHttpMethod"
public let UUHttpSessionErrorRequestUrlKey      = "UUHttpSessionErrorRequestUrl"
public let UUHttpSessionErrorHttpStatusCodeKey  = "UUHttpSessionErrorHttpStatusCode"

class UUErrorFactory
{
    static func createInvalidRequestError(_ request : UUHttpRequest) -> Error
    {
        var md: [String : Any]  = [:]
        
        fillFromRequest(&md, request.httpRequest)
        
        return createError(.invalidRequest, md)
    }
    
    static func wrapNetworkError(_ underlyingError: Error, _ request: UUHttpRequest) -> Error
    {
        var errCode: UUHttpSessionError = .httpFailure
        
        var md: [String : Any]  = [:]
        
        fillFromRequest(&md, request.httpRequest)
        fillFromUnderlyingError(&md, underlyingError)
        
        let nsError = underlyingError as NSError
        if (nsError.domain == NSURLErrorDomain)
        {
            switch (nsError.code)
            {
                case NSURLErrorCannotFindHost:
                    errCode = .cannotFindHost
                
                case NSURLErrorNotConnectedToInternet:
                    errCode = .noInternet
                
                case NSURLErrorTimedOut:
                    errCode = .timedOut
                    
                default:
                    errCode = .httpFailure
            }
        }
        
        return createError(errCode, md)
    }
    
    static func createParseError(_ underlyingError: Error, _ data: Data, _ response: HTTPURLResponse, _ request: URLRequest) -> Error
    {
        var md: [String : Any]  = [:]
        
        fillFromRequest(&md, request)
        fillFromResponse(&md, response)
        fillFromUnderlyingError(&md, underlyingError)
        
        return createError(.parseFailure, md)
    }
   
    private static func createError(_ code: UUHttpSessionError, _ userInfo: [String:Any]?) -> Error
    {
        return NSError(domain: UUHttpSessionErrorDomain, code: code.rawValue, userInfo: userInfo)
    }
    
    private static func fillFromRequest(_ md: inout [String:Any], _ request: URLRequest?)
    {
        if let req = request
        {
            md[UUHttpSessionErrorHttpMethodKey] = req.httpMethod
            md[UUHttpSessionErrorRequestUrlKey] = req.url?.absoluteString
        }
    }
    
    private static func fillFromResponse(_ md: inout [String:Any], _ response: HTTPURLResponse?)
    {
        if let resp = response
        {
            md[UUHttpSessionErrorHttpStatusCodeKey] = resp.statusCode
        }
    }
    
    private static func fillFromUnderlyingError(_ md: inout [String:Any], _ error: Error?)
    {
        if let e = error
        {
            md[NSUnderlyingErrorKey] = e
            md[NSLocalizedDescriptionKey] = e.localizedDescription
            
            let nsError = e as NSError
            md[NSLocalizedRecoverySuggestionErrorKey] = nsError.localizedRecoverySuggestion
        }
    }
    
    
}
