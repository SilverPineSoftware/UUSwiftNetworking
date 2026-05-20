//
//  UUPassthroughResponseHandler.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUPassthroughResponseHandler"

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
