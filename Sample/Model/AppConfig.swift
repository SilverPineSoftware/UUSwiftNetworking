//
//  AppConfig.swift
//  Sample
//
//  Created by Ryan DeVore on 7/1/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

struct AppConfig: Codable, Sendable
{
    let baseUrl: String
    let loginCallbackUrl: String
    
    let shutterstockBaseUrl: String
}

extension AppConfig
{
    static let shared: AppConfig =
    {
        guard let config = load(from: "AppConfig") else
        {
            fatalError("Missing or invalid AppConfig.json")
        }
        
        return config
    }()
    
    static func load(from file: String, bundle: Bundle = .main) -> Self?
    {
        guard let url = bundle.url(forResource: file, withExtension: "json") else
        {
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else
        {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let config = try? decoder.decode(Self.self, from: data)
        return config
    }
}
