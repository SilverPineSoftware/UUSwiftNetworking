//
//  UUEmptyAuthorizationProvider.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/14/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

/// A no-op authorization provider that never attaches an `Authorization` header.
///
/// Use this when a request should be sent without credentials from ``UUHttpAuthorizationProvider``,
/// even though ``UURemoteApi`` normally applies ``UURemoteApiConfig/authorizationProvider`` to
/// every request in ``UURemoteApi/prepareRequest(_:)``.
///
/// Authorization renewal is often a different flow than a normal API call. For example, a token
/// refresh or login endpoint may expect a username and password in the body rather than the
/// bearer token used elsewhere. Setting ``UUHttpRequest/authorizationProvider`` to
/// `UUEmptyAuthorizationProvider()` on that request skips attaching the class-level credentials.
///
/// Typical pattern:
///
/// 1. Set ``UURemoteApiConfig/authorizationProvider`` once on the API client for ordinary calls.
/// 2. In ``UURemoteApi/renewApiAuthorization()``, build the renewal request and assign
///    `UUEmptyAuthorizationProvider()` (or a custom provider for alternate headers) before
///    executing it.
///
/// Example (skip auth on a login request):
///
/// ```swift
/// open override func renewApiAuthorization() async -> UURenewAuthorizationResponse
/// {
///     let request = UUHttpRequest(url: loginUrl, method: .post, body: credentialsBody)
///     request.authorizationProvider = UUEmptyAuthorizationProvider()
///     let response = await executeWithoutAuthorizationRenewal(request)
///     // Parse tokens and update config.authorizationProvider ...
///     return UURenewAuthorizationResponse(didAttempt: true, error: response.httpError)
/// }
/// ```
///
/// ``UURemoteApi/prepareRequest(_:)`` does not replace a request's existing
/// ``UUHttpRequest/authorizationProvider``, so the empty provider remains in effect for that
/// request only.
///
/// - SeeAlso: ``UUHttpAuthorizationProvider``
/// - SeeAlso: ``UURemoteApi/renewApiAuthorization()``
/// - SeeAlso: ``UURemoteApi/executeWithoutAuthorizationRenewal(_:)``
/// - SeeAlso: ``UURemoteApiConfig/authorizationProvider``
/// - SeeAlso: ``UUHttpRequest/authorizationProvider``
open class UUEmptyAuthorizationProvider: UUHttpAuthorizationProvider
{
    /// Always returns `nil`, indicating that no credential string should be sent.
    open override func formatAuthorization() -> String?
    {
        return nil
    }

    /// Intentionally does nothing; no `Authorization` header is added or modified.
    open override func attachAuthorization(_ request: UUHttpRequest) async
    {
        // Do nothing
    }
}
