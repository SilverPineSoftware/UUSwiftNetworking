//
//  UUBinaryDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUBinaryDataParser"

open class UUBinaryDataParser: UUHttpDataParser
{
    public required init()
    {
        
    }
    
    open func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
    {
        return data
    }
}
