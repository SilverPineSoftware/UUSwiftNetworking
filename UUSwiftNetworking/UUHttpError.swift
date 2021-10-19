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
    static func wrapNetworkError(_ underlyingError: Error, _ request: UUHttpRequest) -> Error
    {
        var errCode = UUHttpSessionError.httpFailure
        
        var userInfo : [String : Any]  = [:]
        fillFromRequest(&userInfo, request)
        
        userInfo[NSUnderlyingErrorKey] = underlyingError
        userInfo[NSLocalizedDescriptionKey] = underlyingError.localizedDescription
        
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
            
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = nsError.localizedRecoverySuggestion
        }
        
        return NSError(domain: UUHttpSessionErrorDomain, code: errCode.rawValue, userInfo: userInfo)
    }
    
    static func createParseError(_ underlyingError: Error) -> Error
    {
        var d : [String:Any] = [:]
        //d[UUHttpSessionHttpErrorCodeKey] = NSNumber(value: httpResponseCode)
        //d[UUHttpSessionHttpErrorMessageKey] = HTTPURLResponse.localizedString(forStatusCode: httpResponseCode)
        //d[UUHttpSessionAppResponseKey] = parsedResponse
        //d[NSLocalizedDescriptionKey] = HTTPURLResponse.localizedString(forStatusCode: httpResponseCode)

        return NSError.init(domain: UUHttpSessionErrorDomain, code: UUHttpSessionError.parseFailure.rawValue, userInfo: d)
    }
    
    private static func fillFromRequest(_ md: inout [String:Any], _ request: UUHttpRequest?)
    {
        if let httpRequest = request
        {
            md[UUHttpSessionErrorHttpMethodKey] = httpRequest.httpMethod.rawValue
            md[UUHttpSessionErrorRequestUrlKey] = httpRequest.httpRequest?.url?.absoluteString
        }
    }
    
    private static func fillFromResponse(_ md: inout [String:Any], _ response: UUHttpResponse)
    {
        fillFromRequest(&md, response.httpRequest)
        
        if let httpResponse = response.httpResponse
        {
            md[UUHttpSessionErrorHttpStatusCodeKey] = httpResponse.statusCode
        }
    }
}
