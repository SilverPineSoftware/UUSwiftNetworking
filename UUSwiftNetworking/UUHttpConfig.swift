//
//  UUHttpConfig.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/20/26.
//

import Foundation

public struct UUHttpConfig
{
    public static let shared = UUHttpConfig()
    
    public var defaultTimeout : TimeInterval = 60.0
    public var defaultCachePolicy : URLRequest.CachePolicy = .useProtocolCachePolicy
}
