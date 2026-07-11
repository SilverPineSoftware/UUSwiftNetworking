//
//  AppError.swift
//  Sample
//
//  Created by Ryan DeVore on 7/5/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

enum AppError: Error
{
    case noRefreshToken
    case notSignedIn
    
    case invalidConfigUrl
    case invalidLoginUrl
    case stateCheckFailed
    case apiCallFailed(Error)
    
    case unexpectedError(String)

}

extension AppError: LocalizedError
{
    var errorName: String
    {
        switch (self)
        {
            case .noRefreshToken:
                return "no_refresh_token"
            
            case .notSignedIn:
                return "not_signed_in"
            
            case .invalidConfigUrl:
                return "invalid_config_url"
            
            case .invalidLoginUrl:
                return "invalid_login_url"
            
            case .stateCheckFailed:
                return "state_check_failed"
            
            case .apiCallFailed(_):
                return "api_call_failed"
            
            case .unexpectedError(_):
                return "unexpected_error"
        }
    }
    
    var errorDescription: String?
    {
        switch (self)
        {
            case .noRefreshToken:
                return "No refresh token stored locally"
            
            case .notSignedIn:
                return "There is no active user session"
            
            case .invalidConfigUrl:
                return "Invalid configuration URL"
            
            case .invalidLoginUrl:
                return "Invalid login URL"
            
            case .stateCheckFailed:
                return "State check failed"
            
            case .apiCallFailed(let err):
                return "API call failed: \(err.localizedDescription)"
            
            case .unexpectedError(let message):
                return "Unexpected error: \(message)"
        }
    }
}
