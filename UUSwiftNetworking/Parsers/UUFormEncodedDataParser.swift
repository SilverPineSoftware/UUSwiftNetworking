//
//  UUFormEncodedDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUFormEncodedDataParser"

/// Parses `application/x-www-form-urlencoded` bodies into `[String: Any]` key/value pairs.
///
/// Values are percent-decoded when possible. Keys without `=` are ignored.
open class UUFormEncodedDataParser: UUHttpDataParser
{
    public required init()
    {
    }
    
    open func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
    {
        var parsed: [ String: Any ] = [:]

        if let s = String.init(data: data, encoding: .utf8)
        {
            let components = s.components(separatedBy: "&")
            
            for c in components
            {
                let pair = c.components(separatedBy: "=")
                
                if pair.count == 2
                {
                    if let key = pair.first
                    {
                        if let val = pair.last
                        {
                            parsed[key] = val.removingPercentEncoding
                        }
                    }
                }
            }
        }

        return parsed
    }
}
