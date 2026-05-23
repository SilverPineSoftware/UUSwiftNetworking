//
//  UUHttpDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUHttpDataParser"

public protocol UUHttpDataParser
{
    func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
}
