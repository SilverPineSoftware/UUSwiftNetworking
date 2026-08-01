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
/// ``UURemoteApi/prepareRequest(_:)`` reads this value when preparing ``UUHttpRequest`` objects,
/// assigning ``networkTimeout`` to each request before execution.
///
/// Configure once on the API instance rather than on individual requests:
///
/// ```swift
/// let api = MyRemoteApi()
/// api.config.networkTimeout = 30
/// ```
///
/// Subclasses may expose a more specific config type (for example, API keys or base URLs) while
/// still inheriting these common networking defaults.
open class UURemoteApiConfig
{
    public var baseUrl: String = ""
    
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
    /// let config = UURemoteApiConfig(networkTimeout: 30)
    /// api.config = config
    /// ```
    ///
    /// - Parameters:
    ///   - networkTimeout: The timeout, in seconds, assigned to each request before execution.
    ///     Defaults to ``UUHttpConfig/shared`` ``UUHttpConfig/defaultTimeout``.
    public init(
        baseUrl: String = "",
        networkTimeout: TimeInterval = UUHttpConfig.shared.defaultTimeout
    )
    {
        self.baseUrl = baseUrl
        self.networkTimeout = networkTimeout
    }
}
