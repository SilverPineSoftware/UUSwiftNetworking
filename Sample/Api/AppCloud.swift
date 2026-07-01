//
//  AppCloud.swift
//  Sample
//
//  Created by Ryan DeVore on 6/29/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

// Static facade to serve up real instances of service classes
struct AppCloud
{
    // Enforce singleton
    private init() { }
    
    static let api: UUNetworkingApi = UUNetworkingApiImpl()
}
