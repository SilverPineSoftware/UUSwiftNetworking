//
//  UUNetworkingApi.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/29/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import UUSwiftCore
import UUSwiftNetworking

private let LOG_TAG = "UUNetworkingApi"

//nonisolated
//class UUNetworkingApiConfig: UURemoteApiConfig
//{
//    //var baseUrl: String = "https://uu-networking.spsw.io"
//    //var loginCallbackUrl: String = "uu-networking://login"
//}

struct LoginRequest
{
    let state = UURandom.bytes(length: 32).uuToHexString()
    let callbackUrl: String = "uu-networking://login"
}

struct CompleteLoginRequest: Codable
{
    //let clientId: String
    let ticket: String
    //let codeVerifier: String
    
    //init(clientId: String, ticket: String, codeVerifier: String)
    init(ticket: String)
    {
        //self.clientId = clientId
        self.ticket = ticket
        //self.codeVerifier = codeVerifier
    }
    
    enum CodingKeys: String, CodingKey
    {
        //case clientId = "client_id"
        case ticket
        //case codeVerifier = "code_verifier"
    }
}

struct CompleteLoginResponse: Codable
{
    let accessToken: String
    let tokenType: String
    let expiresAt: String
    let refreshToken: String?
    let idToken: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey
    {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresAt = "expires_at"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case scope
    }
}

struct ServerErrorResponse: Codable
{
    let error: String
    let message: String
    
    enum CodingKeys: CodingKey
    {
        case error
        case message
    }
}


protocol UUNetworkingApi: Sendable
{
    /// Returns the URL that the app needs to open in a secure web browser to log the user into the application.
    func getLoginUrl(_ request: LoginRequest) async -> Result<URL, Error>
    
    func completeLogin(_ request: LoginRequest, _ url: URL) async -> Result<String, Error>
}

final class UUNetworkingApiImpl: UURemoteApi, UUNetworkingApi
{
    private let appConfig: AppConfig
    
    public init(_ config: AppConfig)
    {
        self.appConfig = config
        
        super.init()
        
        self.config.baseUrl = config.baseUrl
    }
    
    func getLoginUrl(_ request: LoginRequest) async -> Result<URL, any Error>
    {
        guard var urlComponents = URLComponents(string: config.baseUrl) else
        {
            return .failure(NSError(domain: "foo", code: -2))
        }
        
        urlComponents.path = "/api/auth/login"
        urlComponents.queryItems = [
            URLQueryItem(name: "redirect_uri", value: request.callbackUrl),
            URLQueryItem(name: "state", value: request.state),
        ]
        
        if let url = urlComponents.url
        {
            return .success(url)
        }
        else
        {
            return .failure(NSError(domain: "foo", code: -3))
        }
    }
    
    
    func completeLogin(_ loginRequest: LoginRequest, _ url: URL) async -> Result<String, any Error>
    {
        let urlPath = url.path(percentEncoded: false)
        UULog.debug(tag: LOG_TAG, message: "URLPath: \(urlPath)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let ticketItem = queryItems.first(where: { $0.name == "ticket" }),
           let ticket = ticketItem.value,
           let stateItem = queryItems.first(where: { $0.name == "state" }),
           let state = stateItem.value else
        {
            return .failure(NSError(domain: "foo", code: -5))
        }
        
        UULog.debug(tag: LOG_TAG, message: "Ticket: \(ticket)")
        UULog.debug(tag: LOG_TAG, message: "State: \(state)")
        
        if (state != loginRequest.state)
        {
            UULog.debug(tag: LOG_TAG, message: "State check failed!, expected: \(loginRequest.state) but received: \(state)")
            return .failure(NSError(domain: "foo", code: -3))
        }
        
        let payload = CompleteLoginRequest(ticket: ticket)
        
        let request = UUCodableHttpRequest<CompleteLoginResponse, ServerErrorResponse>(
            url: "\(self.config.baseUrl)/api/auth/complete",
            method: .post,
            body: UUJsonBody(payload))
        
        let apiResult = await executeTypedWithoutAuthorizationRenewal(request)
        switch (apiResult)
        {
            case .failure(let err):
                UULog.debug(tag: LOG_TAG, message: "Failed to complete login: \(err)")
                return .failure(err)
            
            case .success(let res):
                UULog.debug(tag: LOG_TAG, message: "Successfully completed login: \(res.accessToken)")
                return .success(res.accessToken)
        }
    }
}
