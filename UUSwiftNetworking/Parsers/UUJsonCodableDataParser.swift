//
//  UUJsonCodableDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUJsonCodableDataParser"

open class UUJsonCodableDataParser<T: Codable>: UUHttpDataParser
{
    public required init()
    {
        
    }
    
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
