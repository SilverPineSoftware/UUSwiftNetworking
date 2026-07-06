//
//  AppServices.swift
//  Sample
//
//  Created by Ryan DeVore on 7/1/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

struct AppServices: Sendable
{
    private init() { } // Enforce only singleton usage
    
    
    static let appServer: AppServerApi =
    {
        return UUAppServerApi(AppConfig.shared)
    }()
    
}
