//
//  UUPassthroughResponseHandler.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUPassthroughResponseHandler"

/// Response handler that always parses bodies as raw ``Data`` via ``UUBinaryDataParser``.
///
/// Use for file downloads, binary APIs, or when MIME-based dispatch is not desired.
open class UUPassthroughResponseHandler: UUBaseResponseHandler
{
    public required init()
    {
        super.init()
    }
    
    open override var successParser: UUHttpDataParser
    {
        return UUBinaryDataParser()
    }
    
    open override var errorParser: UUHttpDataParser
    {
        return UUBinaryDataParser()
    }
}
