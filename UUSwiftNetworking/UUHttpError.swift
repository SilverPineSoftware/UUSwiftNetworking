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
}

public let UUHttpSessionErrorDomain           = "UUHttpSessionErrorDomain"
public let UUHttpSessionHttpErrorCodeKey      = "UUHttpSessionHttpErrorCodeKey"
public let UUHttpSessionHttpErrorMessageKey   = "UUHttpSessionHttpErrorMessageKey"
public let UUHttpSessionAppResponseKey        = "UUHttpSessionAppResponseKey"
