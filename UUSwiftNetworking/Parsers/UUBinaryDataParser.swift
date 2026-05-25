//
//  UUBinaryDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUBinaryDataParser"

/// Pass-through parser that returns the raw response ``Data`` unchanged.
///
/// Use for downloads, opaque payloads, or as the default when no MIME-specific decoding is required.
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
