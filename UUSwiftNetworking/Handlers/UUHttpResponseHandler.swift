//
//  UUHttpResponseHandler.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUHttpResponseHandler"

/// Handles completion of an HTTP exchange: logging, parsing, and construction of ``UUHttpResponse``.
///
/// Implementations choose success and error ``UUHttpDataParser`` instances and map transport failures,
/// HTTP status codes, and parser results into a single response object.
public protocol UUHttpResponseHandler
{
    /// Processes URLSession (or test) results into a ``UUHttpResponse``.
    func handleResponse(request: UUHttpRequest, data: Data?, response: URLResponse?, error: Error?) async -> UUHttpResponse
    
    /// Parser used when the HTTP status code is a success (2xx).
    var successParser: UUHttpDataParser { get }
    
    /// Parser used when the HTTP status code is not a success.
    var errorParser: UUHttpDataParser { get }
}
