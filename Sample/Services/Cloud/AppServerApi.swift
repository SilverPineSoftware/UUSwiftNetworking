//
//  AppServerApi.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/29/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import UUSwiftCore
import UUSwiftNetworking

private let LOG_TAG = "AppServerApi"


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

protocol UUJsonDateDecoder: Sendable
{
    func decode(_ decoder: any Decoder) throws -> Date
}

struct JsonDateDecoderImpl: UUJsonDateDecoder
{
    private let formatters: [DateFormatter]
    
    init(_ formatters: [DateFormatter])
    {
        self.formatters = formatters
    }
    
    func decode(_ decoder: any Decoder) throws -> Date
    {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        
        for formatter in self.formatters
        {
            UULog.debug(tag: LOG_TAG, message: "Trying to decode \(dateString) with formatter: \(formatter)")
            if let date = formatter.date(from: dateString)
            {
                return date
            }
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unable to parse date string: \(dateString)")
    }
}

nonisolated class AppServerResponseHandler<ResponseType: Codable, ErrorType: Codable>: UUJsonCodableResponseHandler<ResponseType, ErrorType>
{
    private let jsonDateDecoder = JsonDateDecoderImpl([
        DateFormatter.uuCachedFormatter(UUDate.Formats.rfc3339WithMillis)
    ])
    
    override init()
    {
        super.init()
        
        jsonDecoder.dateDecodingStrategy = .custom({ decoder in
            
            try self.jsonDateDecoder.decode(decoder)
        })
    }
}

extension AppServerDTO.CompleteLoginResponse
{
    var asAppUser: AppUser
    {
        AppUser(
            id: user.id,
            email: user.email,
            displayName: user.displayName,
            role: user.role,
            isSuperUser: user.isSuperUser,
            tokenValidUntil: expiresAt)
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

struct ConfigItem: Codable
{
    let key: String
    let value: String
}

protocol AppServerApi: Sendable
{
    /// Returns the URL that the app needs to open in a secure web browser to log the user into the application.
    func getLoginUrl(_ request: LoginRequest) async -> Result<URL, AppError>
    
    func completeLogin(_ request: LoginRequest, _ url: URL) async -> Result<AppUser, AppError>
    
    func logout() async -> AppError?
    
    func getMe() async -> Result<AppUser, AppError>
    
    func getConfig(_ key: String) async -> Result<String, AppError>
    func putConfig(_ key: String, _ value: String) async -> AppError?
    func deleteConfig(_ key: String) async -> AppError?
}

nonisolated
class KeychainAuthorizationProvider: UUHttpAuthorizationProvider, @unchecked Sendable
{
    private static let accessTokenKey = "networking_api.access_token"
    private static let refreshTokenKey = "networking_api.refresh_token"
    
    override func loadAuthorization() async -> Result<UUHttpAuthorization?, Error>
    {
        if let accessToken = await readAccessToken()
        {
            return .success(UUHttpAuthorization(authorization: accessToken))
        }
        
        return .success(nil)
    }
    
    func readAccessToken() async -> String?
    {
        guard let accessTokenBytes = await UUSecurity.keychain.read(key: Self.accessTokenKey).uuSuccess else
        {
            return nil
        }
        
        guard let accessToken = String(data: accessTokenBytes, encoding: .utf8) else
        {
            return nil
        }
        
        return accessToken
    }
    
    func readAccessTokenExpiration() async -> Date?
    {
        return await readAccessToken()?.asSignedJsonWebToken?.expiration
    }
    
    func isAuthorizationNeeded() async -> Bool
    {
        return await readAccessTokenExpiration() != nil
    }
    
    func readRefreshToken() async -> String?
    {
        guard let refreshTokenBytes = await UUSecurity.keychain.read(key: Self.refreshTokenKey).uuSuccess else
        {
            return nil
        }
        
        guard let refreshToken = String(data: refreshTokenBytes, encoding: .utf8) else
        {
            return nil
        }
        
        return refreshToken
    }
    
    func saveLoginResponse(_ loginResponse: AppServerDTO.CompleteLoginResponse) async
    {
        let accessTokenBytes = Data(loginResponse.accessToken.utf8)
        _ = await UUSecurity.keychain.write(key: Self.accessTokenKey, accessLevel: .afterFirstUnlockThisDeviceOnly, data: accessTokenBytes)
        
        if let refreshToken = loginResponse.refreshToken
        {
            let refreshTokenBytes = Data(refreshToken.utf8)
            _ = await UUSecurity.keychain.write(key: Self.refreshTokenKey, accessLevel: .afterFirstUnlockThisDeviceOnly, data: refreshTokenBytes)
        }
    }
    
    func reset() async
    {
        _ = await UUSecurity.keychain.clear(key: Self.accessTokenKey)
        _ = await UUSecurity.keychain.clear(key: Self.refreshTokenKey)
    }
}

final class UUAppServerApi: UURemoteApi, AppServerApi
{
    private let appConfig: AppConfig
    private let authProvider: KeychainAuthorizationProvider
    
    public init(_ config: AppConfig)
    {
        self.appConfig = config
        self.authProvider = KeychainAuthorizationProvider()
        
        super.init()
        
        self.config.baseUrl = config.baseUrl
        self.authorizationProvider = authProvider
    }
    
    //MARK: UURemoteApi Overrides
    
    override func prepareTypedRequest<SuccessType: Codable, ErrorType: Codable>(
        _ request: UUCodableHttpRequest<SuccessType, ErrorType>) async
    {
        await super.prepareTypedRequest(request)
        
        request.responseHandler = AppServerResponseHandler<SuccessType, ErrorType>()
    }
    
    override func isApiAuthorizationNeeded() async -> Bool
    {
        return await authProvider.isAuthorizationNeeded()
    }
    
    override func renewApiAuthorization() async -> UURenewAuthorizationResponse
    {
        guard let refreshToken = await authProvider.readRefreshToken() else
        {
            return UURenewAuthorizationResponse(didAttempt: false, error: AppError.noRefreshToken)
        }
        
        let payload = AppServerDTO.RefreshTokenRequest(refreshToken: refreshToken)
        
        let request = UUCodableHttpRequest<AppServerDTO.CompleteLoginResponse, ServerErrorResponse>(
            url: "\(self.config.baseUrl)/api/auth/refresh",
            method: .post,
            body: UUJsonBody(payload))
        
        let apiResult = await executeTypedWithoutAuthorizationRenewal(request)
        switch (apiResult)
        {
            case .failure(let err):
                UULog.debug(tag: LOG_TAG, message: "Failed to refresh token: \(err)")
                return UURenewAuthorizationResponse(didAttempt: true, error: err)
            
            case .success(let res):
                UULog.debug(tag: LOG_TAG, message: "Successfully refreshed token: \(res.accessToken)")
            
                await authProvider.saveLoginResponse(res)
                return UURenewAuthorizationResponse(didAttempt: true, error: nil)
        }
    }
    
    //MARK: UUNetworkApi implementation
    
    func getLoginUrl(_ request: LoginRequest) async -> Result<URL, AppError>
    {
        guard var urlComponents = URLComponents(string: config.baseUrl) else
        {
            return .failure(.invalidConfigUrl)
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
            return .failure(.invalidLoginUrl)
        }
    }
    
    func completeLogin(_ loginRequest: LoginRequest, _ url: URL) async -> Result<AppUser, AppError>
    {
        let urlPath = url.path
        UULog.debug(tag: LOG_TAG, message: "URLPath: \(urlPath)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let ticketItem = queryItems.first(where: { $0.name == "ticket" }),
           let ticket = ticketItem.value,
           let stateItem = queryItems.first(where: { $0.name == "state" }),
           let state = stateItem.value else
        {
            return .failure(.unexpectedError("missing ticket or state"))
        }
        
        UULog.debug(tag: LOG_TAG, message: "Ticket: \(ticket)")
        UULog.debug(tag: LOG_TAG, message: "State: \(state)")
        
        if (state != loginRequest.state)
        {
            UULog.debug(tag: LOG_TAG, message: "State check failed!, expected: \(loginRequest.state) but received: \(state)")
            return .failure(.stateCheckFailed)
        }
        
        let payload = CompleteLoginRequest(ticket: ticket)
        
        let request = UUCodableHttpRequest<AppServerDTO.CompleteLoginResponse, ServerErrorResponse>(
            url: "\(self.config.baseUrl)/api/auth/complete",
            method: .post,
            body: UUJsonBody(payload))
        
        let apiResult = await executeTypedWithoutAuthorizationRenewal(request)
        switch (apiResult)
        {
            case .failure(let err):
                UULog.debug(tag: LOG_TAG, message: "Failed to complete login: \(err)")
                return .failure(.apiCallFailed(err))
            
            case .success(let res):
                UULog.debug(tag: LOG_TAG, message: "Successfully completed login: \(res.accessToken)")
            
                await authProvider.saveLoginResponse(res)
                    return .success(res.asAppUser)
        }
    }
    
    func logout() async -> AppError?
    {
        await authProvider.reset()
        return nil
    }
    
    func getMe() async -> Result<AppUser, AppError>
    {
        let request = UUCodableHttpRequest<AppServerDTO.GetMeResponse, ServerErrorResponse>(
            url: "\(self.config.baseUrl)/api/me",
            method: .get)
        
        let apiResult = await executeTyped(request)
        switch (apiResult)
        {
            case .failure(let err):
                UULog.debug(tag: LOG_TAG, message: "Failed to get me: \(err)")
                return .failure(.apiCallFailed(err))
            
            case .success(let response):
                UULog.debug(tag: LOG_TAG, message: "Successfully fetched me: \(response)")
            
                guard let accessTokenExpiration = await authProvider.readAccessTokenExpiration() else
                {
                    return .failure(.notSignedIn)
                }
            
                return .success(AppUser(
                    id: response.user.id,
                    email: response.user.email,
                    displayName: response.user.displayName,
                    role: response.user.role,
                    isSuperUser: response.user.isSuperUser,
                    tokenValidUntil: accessTokenExpiration))
        }
    }
    
    func getConfig(_ key: String) async -> Result<String, AppError>
    {
        let request = UUCodableHttpRequest<ConfigItem, ServerErrorResponse>(
            url: "\(self.config.baseUrl)/api/config/\(key)",
            method: .get)
        
        let apiResult = await executeTyped(request)
        switch (apiResult)
        {
            case .failure(let err):
                UULog.debug(tag: LOG_TAG, message: "Failed to get config: \(err)")
                return .failure(.apiCallFailed(err))
            
            case .success(let response):
                UULog.debug(tag: LOG_TAG, message: "Successfully fetched config: \(response)")
            
                return .success(response.value)
        }
    }
    
    func putConfig(_ key: String, _ value: String) async -> AppError?
    {
        let request = UUCodableHttpRequest<UUEmptyCodable, ServerErrorResponse>(
            url: "\(self.config.baseUrl)/api/config/\(key)",
            method: .put,
            body: UUJsonBody(ConfigItem(key: key, value: value)))
        
        let apiResult = await executeTyped(request)
        switch (apiResult)
        {
            case .failure(let err):
                UULog.debug(tag: LOG_TAG, message: "Failed to put config: \(err)")
                return .apiCallFailed(err)
            
            case .success(let response):
                UULog.debug(tag: LOG_TAG, message: "Successfully updated config: \(response)")
            
                return nil
        }
    }
    
    func deleteConfig(_ key: String) async -> AppError?
    {
        let request = UUCodableHttpRequest<UUEmptyCodable, ServerErrorResponse>(
            url: "\(self.config.baseUrl)/api/config/\(key)",
            method: .delete)
        
        let apiResult = await executeTyped(request)
        switch (apiResult)
        {
            case .failure(let err):
                UULog.debug(tag: LOG_TAG, message: "Failed to put config: \(err)")
                return .apiCallFailed(err)
            
            case .success(let response):
                UULog.debug(tag: LOG_TAG, message: "Successfully updated config: \(response)")
            
                return nil
        }
    }
}


fileprivate extension String
{
    var asSignedJsonWebToken: UUSignedJsonWebToken?
    {
        UUSignedJsonWebToken.parse(self).uuSuccess
    }
}
