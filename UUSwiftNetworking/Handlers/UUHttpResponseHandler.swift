//
//  UUHttpResponseHandler.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUHttpResponseHandler"

public protocol UUHttpResponseHandler
{
    func handleResponse(request: UUHttpRequest, data: Data?, response: URLResponse?, error: Error?, completion: @escaping (UUHttpResponse)->())
    
    var successParser: UUHttpDataParser { get }
    var errorParser: UUHttpDataParser { get }
}
