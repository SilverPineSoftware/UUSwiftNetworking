//
//  MockNetworkingApi.swift
//  Sample
//
//  Created by Ryan DeVore on 7/5/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

class MockNetworkingApi: AppServerApi
{
    var getLoginUrlResult: Result<URL, AppError> = .failure(.unexpectedError("Mock not implemented"))
    var completeLoginResult: Result<AppUser, AppError> = .failure(.unexpectedError("Mock not implemented"))
    var getMeResult: Result<AppUser, AppError> = .failure(.unexpectedError("Mock not implemented"))
    var getConfigResult: Result<String, AppError> = .failure(.unexpectedError("Mock not implemented"))
    var putConfigResult: AppError? = .unexpectedError("Mock not implemented")
    var deleteConfigResult: AppError? = .unexpectedError("Mock not implemented")
    var logoutResult: AppError? = .unexpectedError("Mock not implemented")
    
    func getLoginUrl(_ request: LoginRequest) async -> Result<URL, AppError>
    {
        return getLoginUrlResult
    }
    
    func completeLogin(_ request: LoginRequest, _ url: URL) async -> Result<AppUser, AppError>
    {
        return completeLoginResult
    }
    
    func logout() async -> AppError?
    {
        return logoutResult
    }
    
    func getMe() async -> Result<AppUser, AppError>
    {
        return getMeResult
    }
    
    func getConfig(_ key: String) async -> Result<String, AppError>
    {
        return getConfigResult
    }
    
    func putConfig(_ key: String, _ value: String) async -> AppError?
    {
        return putConfigResult
    }
    
    func deleteConfig(_ key: String) async -> AppError?
    {
        return deleteConfigResult
    }
}
