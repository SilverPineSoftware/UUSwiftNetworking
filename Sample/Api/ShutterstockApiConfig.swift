//
//  ShutterstockApiConfig.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/7/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

nonisolated public struct ShutterstockApiConfig
{
    var clientKey: String = ""
    var clientSecret: String = ""
    
    init(
        clientKey: String = "",
        clientSecret: String = "")
    {
        self.clientKey = clientKey
        self.clientSecret = clientSecret
    }
}
