//
//  UURemoteApiConfig.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/13/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

/// Shared configuration applied to every request sent through a ``UURemoteApi`` instance.
///
/// ``UURemoteApi/prepareRequest(_:)`` reads this value when preparing ``UUHttpRequest`` objects:
/// the authorization provider is copied onto requests that do not already specify one, and
/// ``networkTimeout`` is assigned to each request before execution.
///
/// Configure once on the API instance rather than on individual requests:
///
/// ```swift
/// let api = MyRemoteApi()
/// api.config.authorizationProvider = UUBasicAuthorizationProvider(userName: "user", password: "pass")
/// api.config.networkTimeout = 30
/// ```
///
/// Subclasses may expose a more specific config type (for example, API keys or base URLs) while
/// still inheriting these common networking defaults.
public struct UURemoteApiConfig
{
    /// The authorization provider applied to requests that do not define their own.
    ///
    /// ``UURemoteApi/prepareRequest(_:)`` assigns this value to
    /// ``UUHttpRequest/authorizationProvider`` only when the request's provider is `nil`.
    /// Requests with an explicit provider are left unchanged.
    ///
    /// Typical values include ``UUBasicAuthorizationProvider`` or a custom
    /// ``UUHttpAuthorizationProvider`` subclass that attaches bearer tokens or signed headers.
    public var authorizationProvider: UUHttpAuthorizationProvider? = nil
    
    /// The request timeout applied by ``UURemoteApi/prepareRequest(_:)`` to each ``UUHttpRequest``.
    ///
    /// Defaults to ``UUHttpConfig/shared`` ``UUHttpConfig/defaultTimeout``. Individual requests
    /// may still override ``UUHttpRequest/timeout`` before execution if a call site needs a
    /// different value.
    public var networkTimeout: TimeInterval = UUHttpConfig.shared.defaultTimeout
    
    /// Creates a remote API configuration with shared request defaults.
    ///
    /// Use this initializer when constructing a ``UURemoteApiConfig`` value directly—for example,
    /// when injecting config into a ``UURemoteApi`` subclass or test double—instead of mutating
    /// properties after creation.
    ///
    /// Values are applied by ``UURemoteApi/prepareRequest(_:)`` to each ``UUHttpRequest`` before
    /// it is sent through ``UURemoteApi/session``.
    ///
    /// ```swift
    /// let config = UURemoteApiConfig(
    ///     authorizationProvider: UUBasicAuthorizationProvider(userName: "user", password: "pass"),
    ///     networkTimeout: 30
    /// )
    /// api.config = config
    /// ```
    ///
    /// - Parameters:
    ///   - authorizationProvider: The provider copied onto requests whose
    ///     ``UUHttpRequest/authorizationProvider`` is `nil`. Pass `nil` for unauthenticated APIs.
    ///   - networkTimeout: The timeout, in seconds, assigned to each request before execution.
    ///     Defaults to ``UUHttpConfig/shared`` ``UUHttpConfig/defaultTimeout``.
    public init(
        authorizationProvider: UUHttpAuthorizationProvider? = nil,
        networkTimeout: TimeInterval = UUHttpConfig.shared.defaultTimeout
    )
    {
        self.authorizationProvider = authorizationProvider
        self.networkTimeout = networkTimeout
    }
}
