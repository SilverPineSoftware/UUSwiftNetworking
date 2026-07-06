//
//  AppUser.swift
//  Sample
//
//  Created by Ryan DeVore on 7/5/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

struct AppUser
{
    let id: String
    let email: String
    let displayName: String
    let role: String
    let isSuperUser: Bool
    
    let tokenValidUntil: Date
    
    init(id: String, email: String, displayName: String, role: String, isSuperUser: Bool, tokenValidUntil: Date)
    {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.isSuperUser = isSuperUser
        self.tokenValidUntil = tokenValidUntil
    }
}
