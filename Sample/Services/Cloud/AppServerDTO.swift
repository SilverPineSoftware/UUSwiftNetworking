//
//  AppServerDTO.swift
//  Sample
//
//  Created by Ryan DeVore on 7/6/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

enum AppServerDTO
{
    struct RefreshTokenRequest: Codable
    {
        let refreshToken: String
        
        init(refreshToken: String)
        {
            self.refreshToken = refreshToken
        }
        
        enum CodingKeys: String, CodingKey
        {
            case refreshToken = "refresh_token"
        }
    }

    struct CompleteLoginResponse: Codable
    {
        let accessToken: String
        let tokenType: String
        let expiresAt: Date
        let refreshToken: String?
        let idToken: String?
        let scope: String?
        let user: User
        
        enum CodingKeys: String, CodingKey
        {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresAt = "expires_at"
            case refreshToken = "refresh_token"
            case idToken = "id_token"
            case scope
            case user
        }
    }
    
    struct Auth: Codable
    {
        let role: String
        let roles: [String]
        let isSuperUser: Bool
        
        enum CodingKeys: String, CodingKey
        {
            case role
            case roles
            case isSuperUser = "is_superuser"
        }
    }
    
    struct User: Codable
    {
        let id: String
        let email: String
        let displayName: String
        let role: String
        let isSuperUser: Bool
        
        enum CodingKeys: String, CodingKey
        {
            case id
            case email
            case displayName = "display_name"
            case role
            case isSuperUser = "is_superuser"
        }
    }
    
    struct GetMeResponse: Codable
    {
        let user: User
        let auth: Auth
    }
}
