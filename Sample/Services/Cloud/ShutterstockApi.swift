//
//  ShutterstockApi.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/3/26.
//

import Foundation
import UUSwiftCore
import UUSwiftNetworking

nonisolated private let LOG_TAG = "ShutterstockApi"

nonisolated final class ShutterstockAuthorizationProvider: UUHttpAuthorizationProvider, @unchecked Sendable
{
    private let credentialsStore: ShutterstockCredentialsStore
    
    init(credentialsStore: ShutterstockCredentialsStore)
    {
        self.credentialsStore = credentialsStore
        
        super.init()
    }
    
    override func loadAuthorization() async -> Result<UUHttpAuthorization?, Error>
    {
        guard case .success(let credentials) = await credentialsStore.loadCredentials(),
              credentials.isComplete else
        {
            return .success(nil)
        }
        
        return .success(UUBasicAuthorization(
            userName: credentials.clientKey,
            password: credentials.clientSecret))
    }
}

protocol ShutterstockApi: Sendable
{
    func loadCredentials() async -> Result<ShutterstockCredentials, Error>
    func saveCredentials(_ credentials: ShutterstockCredentials) async -> Error?
    func clearCredentials() async -> Error?
    func searchImagePage(query: String, page: Int, count: Int, large: Bool) async -> Result<[String], Error>
}

final class UUShutterstockApi: UURemoteApi, ShutterstockApi, @unchecked Sendable
{
    private static let maxPerPage = 500
    
    private let credentialsStore: ShutterstockCredentialsStore
    
    init(
        baseUrl: String,
        credentialsStore: ShutterstockCredentialsStore = UUShutterstockCredentialsStore())
    {
        self.credentialsStore = credentialsStore
        
        super.init()
        
        self.config.baseUrl = baseUrl
        self.authorizationProvider = ShutterstockAuthorizationProvider(credentialsStore: credentialsStore)
    }
    
    func formatUrl(_ endpoint: ShutterstockEndpoint) -> String
    {
        return "\(self.config.baseUrl)\(endpoint.rawValue)"
    }
    
    func loadCredentials() async -> Result<ShutterstockCredentials, Error>
    {
        return await credentialsStore.loadCredentials()
    }
    
    func saveCredentials(_ credentials: ShutterstockCredentials) async -> Error?
    {
        return await credentialsStore.saveCredentials(credentials)
    }
    
    func clearCredentials() async -> Error?
    {
        return await credentialsStore.clearCredentials()
    }
    
    func searchImagePage(query: String, page: Int, count: Int, large: Bool) async -> Result<[String], Error>
    {
        //https://api.shutterstock.com/v2/images/search
        let req = UUCodableHttpRequest<ShutterstockDTO.SearchImagesResponse, ShutterstockDTO.Error>(
            url: formatUrl(ShutterstockEndpoint.searchImages))
        
        var args: [URLQueryItem] = []
        args.append(.init(name: "page", value: "\(page)"))
        args.append(.init(name: "per_page", value: "\(min(count, Self.maxPerPage))"))
        args.append(.init(name: "query", value: "\(query)"))
     
        req.queryItems = args
        
        let result = await executeTyped(req)
        
        switch (result)
        {
            case .success(let searchResult):
                UULog.debug(tag: LOG_TAG, message: "Success!")
            
                let allAssets = searchResult.data.compactMap(\.assets)
                
                if (large)
                {
                    let largeAssets = allAssets.compactMap(\.preview1500)
                    return .success(largeAssets.compactMap(\.url))
                }
                else
                {
                    let smallAssets = allAssets.compactMap(\.smallThumb)
                    return .success(smallAssets.compactMap(\.url))
                }
            
            case .failure(let error):
                // TODO: Translate into api specific error
                UULog.debug(tag: LOG_TAG, message: "Api returned an error: \(error)")
                return .failure(error)
        }
    }
}

enum ShutterstockEndpoint: String
{
    case searchImages = "/v2/images/search"    
}
