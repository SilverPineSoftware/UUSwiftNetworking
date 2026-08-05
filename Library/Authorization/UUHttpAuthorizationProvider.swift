//
//  UUHttpAuthorizationProvider.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 8/1/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

/// Async source of request authorization for ``UURemoteApi``.
///
/// Raw ``UUHttpRequest`` values use ``UUHttpRequest/authorization`` directly. Higher-level API
/// clients use a provider when credentials need to be loaded from storage, refreshed, or otherwise
/// resolved at request time.
open class UUHttpAuthorizationProvider
{
    public init()
    {
        
    }
    
    /// Loads the authorization model that should be applied to a request.
    ///
    /// The default implementation returns `nil`, meaning no authorization is available.
    open func loadAuthorization() async -> Result<UUHttpAuthorization?, Error>
    {
        return .success(nil)
    }
    
    /// Saves an authorization model for later calls to ``loadAuthorization()``.
    ///
    /// Providers backed by read-only sources may leave the default no-op behavior.
    open func saveAuthorization(_ authorization: UUHttpAuthorization) async -> Error?
    {
        return nil
    }
    
    /// Clears stored authorization.
    ///
    /// Providers backed by read-only sources may leave the default no-op behavior.
    open func clearAuthorization() async -> Error?
    {
        return nil
    }
}

/// In-memory authorization provider for simple API clients and tests.
open class UUStaticHttpAuthorizationProvider: UUHttpAuthorizationProvider
{
    public var authorization: UUHttpAuthorization?
    
    public init(_ authorization: UUHttpAuthorization? = nil)
    {
        self.authorization = authorization
        
        super.init()
    }
    
    open override func loadAuthorization() async -> Result<UUHttpAuthorization?, Error>
    {
        return .success(authorization)
    }
    
    open override func saveAuthorization(_ authorization: UUHttpAuthorization) async -> Error?
    {
        self.authorization = authorization
        return nil
    }
    
    open override func clearAuthorization() async -> Error?
    {
        authorization = nil
        return nil
    }
}
