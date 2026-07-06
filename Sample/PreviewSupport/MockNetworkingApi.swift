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
    var getLoginUrlResult: Result<URL, AppServerError> = .failure(.unexpectedError("Mock not implemented"))
    var completeLoginResult: Result<AppServerDTO.User, AppServerError> = .failure(.unexpectedError("Mock not implemented"))
    var getMeResult: Result<AppServerDTO.User, AppServerError> = .failure(.unexpectedError("Mock not implemented"))
    var getConfigResult: Result<String, AppServerError> = .failure(.unexpectedError("Mock not implemented"))
    var putConfigResult: AppServerError? = .unexpectedError("Mock not implemented")
    var deleteConfigResult: AppServerError? = .unexpectedError("Mock not implemented")
    
    func getLoginUrl(_ request: LoginRequest) async -> Result<URL, AppServerError>
    {
        return getLoginUrlResult
    }
    
    func completeLogin(_ request: LoginRequest, _ url: URL) async -> Result<AppServerDTO.User, AppServerError>
    {
        return completeLoginResult
    }
    
    func getMe() async -> Result<AppServerDTO.User, AppServerError>
    {
        return getMeResult
    }
    
    func getConfig(_ key: String) async -> Result<String, AppServerError>
    {
        return getConfigResult
    }
    
    func putConfig(_ key: String) async -> AppServerError?
    {
        return putConfigResult
    }
    
    func deleteConfig(_ key: String) async -> AppServerError?
    {
        return deleteConfigResult
    }
}
