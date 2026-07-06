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
    
    /*
    private static func decodeDate(from decoder: Decoder) throws -> Date
    {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        
        if let date = makeISO8601DateFormatter(includeFractionalSeconds: true).date(from: dateString)
        {
            return date
        }
        
        if let date = makeISO8601DateFormatter(includeFractionalSeconds: false).date(from: dateString)
        {
            return date
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected an ISO 8601 date string, but found: \(dateString)")
    }
    
    private static func makeISO8601DateFormatter(includeFractionalSeconds: Bool) -> ISO8601DateFormatter
    {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = includeFractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter
    }*/
}

/*
extension UUCodableHttpRequest
{
    func useAppServerJSONDecoder()
    {
        guard let responseHandler = responseHandler as? UUJsonCodableResponseHandler<SuccessType, ErrorType> else
        {
            return
        }
        
        responseHandler.jsonDecoder = AppServerJSONDecoder.make()
    }
}*/

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
    
    func getMe() async -> Result<AppUser, AppError>
    
    func getConfig(_ key: String) async -> Result<String, AppError>
    func putConfig(_ key: String, _ value: String) async -> AppError?
    func deleteConfig(_ key: String) async -> AppError?
}

nonisolated
class KeychainAuthorizationProvider: UUHttpAuthorizationProvider
{
    private static let accessTokenKey = "networking_api.access_token"
    private static let refreshTokenKey = "networking_api.refresh_token"
    
    var refreshToken: String? = nil
    
    override func attachAuthorization(_ request: UUHttpRequest) async
    {
        await readAccessToken()
        await super.attachAuthorization(request)
    }
    
    func readAccessToken() async
    {
        guard let accessTokenBytes = await UUSecurity.keychain.read(key: Self.accessTokenKey).uuSuccess else
        {
            return
        }
        
        guard let accessToken = String(data: accessTokenBytes, encoding: .utf8) else
        {
            return
        }
        
        self.authorization = accessToken
    }
    
    func readRefreshToken() async
    {
        guard let refreshTokenBytes = await UUSecurity.keychain.read(key: Self.refreshTokenKey).uuSuccess else
        {
            return
        }
        
        guard let refreshToken = String(data: refreshTokenBytes, encoding: .utf8) else
        {
            return
        }
        
        self.refreshToken = refreshToken
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
        await authProvider.readAccessToken()
        await authProvider.readRefreshToken()
        return (authProvider.authorization == nil || authProvider.refreshToken == nil)
    }
    
    override func renewApiAuthorization() async -> UURenewAuthorizationResponse
    {
        await authProvider.readRefreshToken()
        
        guard let refreshToken = authProvider.refreshToken else
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
        let urlPath = url.path(percentEncoded: false)
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
            
            return .success(AppUser(
                id: response.user.id,
                email: response.user.email,
                displayName: response.user.displayName,
                role: response.user.role,
                isSuperUser: response.user.isSuperUser,
                tokenValidUntil: Date()))
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
