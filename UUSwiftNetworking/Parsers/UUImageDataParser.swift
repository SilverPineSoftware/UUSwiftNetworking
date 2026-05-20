//
//  UUImageDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUImageDataParser"

open class UUImageDataParser: UUHttpDataParser
{
    public required init()
    {
        
    }
    
    open func parse(data: Data, response: HTTPURLResponse, request: URLRequest, completion: @escaping (Any?)->())
    {
        completion(UUImage(data: data))
    }
}
