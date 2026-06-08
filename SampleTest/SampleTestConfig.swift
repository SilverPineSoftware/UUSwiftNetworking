//
//  SampleTestConfig.swift
//  UUSwiftNetworkingSampleTests
//
//  Created by Ryan DeVore on 6/7/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

final class SampleTestConfig: Codable
{
    let shutterstockClientKey: String
    let shutterstockClientSecret: String
    
    enum CodingKeys: String, CodingKey
    {
        case shutterstockClientKey = "shutterstock_client_key"
        case shutterstockClientSecret = "shutterstock_client_secret"
    }
    
    static func load(from file: String) -> Self?
    {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: file, withExtension: "json") else
        {
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else
        {
            return nil
        }
        
        let config = try? JSONDecoder().decode(Self.self, from: data)
        return config
    }
}
