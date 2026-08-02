//
//  ShutterstockApiConfig.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/7/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation


public struct ShutterstockApiConfig
{
    let baseUrl: String
}

/*
import UUSwiftNetworking

nonisolated public struct ShutterstockApiConfig: Codable
{
    private static let UserDefaultsKey = "shutterstock-api-config"
    
    var clientKey: String = ""
    var clientSecret: String = ""
    
    init(
        clientKey: String = "",
        clientSecret: String = "")
    {
        self.clientKey = clientKey
        self.clientSecret = clientSecret
    }
    
    enum CodingKeys: String, CodingKey
    {
        case clientKey = "client_key"
        case clientSecret = "client_secret"
    }
    
//    var apiConfig: UURemoteApiConfig
//    {
//        var cfg = UURemoteApiConfig()
//        return cfg
//    }
    
    static func load() -> Self
    {
        guard let rawData = UserDefaults.standard.data(forKey: UserDefaultsKey) else
        {
            return Self()
        }
        
        let decoded = try? JSONDecoder().decode(Self.self, from: rawData)
        return decoded ?? Self()
    }
    
    func save()
    {
        if let encoded = try? JSONEncoder().encode(self)
        {
            UserDefaults.standard.set(encoded, forKey: Self.UserDefaultsKey)
            UserDefaults.standard.synchronize()
        }
    }
}
*/
