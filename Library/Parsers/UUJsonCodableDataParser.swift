//
//  UUJsonCodableDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUJsonCodableDataParser"

/// Decodes JSON response bodies into a specific `Codable` type using ``JSONDecoder``.
///
/// On decode failure, returns a parse ``Error`` from ``UUErrorFactory/createParseError(_:_:_:_:)`` so
/// ``UUBaseResponseHandler`` can attach it to ``UUHttpResponse/httpError``.
open class UUJsonCodableDataParser<T: Codable>: UUHttpDataParser
{
    public required init()
    {
    }
    
    /// Decoder used for all parse operations; assign before calling ``parse(data:response:request:)``.
    public var jsonDecoder: JSONDecoder = JSONDecoder()
    
    open func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
    {
        var result: Any? = nil
        
        do
        {
            result = try jsonDecoder.decode(T.self, from: data)
        }
        catch let err
        {
            result = UUErrorFactory.createParseError(err, data, response, request)
        }
        
        return result
    }
}
