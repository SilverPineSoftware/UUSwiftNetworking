//
//  UUJsonDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUJsonDataParser"

/// Parses JSON response bodies into Foundation objects (`[String: Any]`, `[Any]`, `NSNumber`, etc.).
///
/// Uses ``JSONSerialization`` with ``JSONSerialization.ReadingOptions.fragmentsAllowed``.
/// Returns `nil` when JSON is malformed (errors are logged, not surfaced as ``UUHttpResponse`` errors).
open class UUJsonDataParser: UUHttpDataParser
{
    public required init()
    {
    }
    
    open func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
    {
        var result: Any? = nil
        
        do
        {
            result = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        }
        catch (let err)
        {
            UULog.debug(tag: LOG_TAG, message: "Error deserializing JSON: \(String(describing: err))")
        }

        return result
    }
}
