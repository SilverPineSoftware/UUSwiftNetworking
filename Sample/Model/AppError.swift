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
    
    case invalidConfigUrl
    case invalidLoginUrl
    case stateCheckFailed
    case apiCallFailed(Error)
    
    case unexpectedError(String)

}

extension AppError: LocalizedError
{
    var errorDescription: String?
    {
        switch (self)
        {
            case .noRefreshToken:
                return "No refresh token stored locally"
            
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
