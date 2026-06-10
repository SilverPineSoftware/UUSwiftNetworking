//
//  ShutterstockViewModel.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/9/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import Combine

class ShutterstockViewModel: ObservableObject
{
    @Published var showConfig: Bool = false
    
    @Published var clientKey: String = ""
    {
        didSet
        {
            var cfg = ShutterstockApiConfig.load()
            cfg.clientKey = clientKey
            cfg.save()
        }
    }
    
    @Published var clientSecret: String = ""
    {
        didSet
        {
            var cfg = ShutterstockApiConfig.load()
            cfg.clientSecret = clientSecret
            cfg.save()
        }
    }
    
    init()
    {
        let cfg = ShutterstockApiConfig.load()
        clientKey = cfg.clientKey
        clientSecret = cfg.clientSecret
    }

}
