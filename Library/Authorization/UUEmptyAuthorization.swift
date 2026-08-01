//
//  UUEmptyAuthorization.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/14/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

/// A no-op authorization model that never attaches an `Authorization` header.
///
/// Use this when a request should be sent without credentials from ``UURemoteApi/authorizationProvider``,
/// even though the API normally applies provider-loaded authorization to every request in
/// ``UURemoteApi/prepareRequest(_:)``.
///
/// Authorization renewal is often a different flow than a normal API call. For example, a token
/// refresh or login endpoint may expect a username and password in the body rather than the
/// bearer token used elsewhere. Setting ``UUHttpRequest/authorization`` to
/// `UUEmptyAuthorization()` on that request skips attaching the class-level credentials.
///
/// Typical pattern:
///
/// 1. Set ``UURemoteApi/authorizationProvider`` once on the API client for ordinary calls.
/// 2. In ``UURemoteApi/renewApiAuthorization()``, build the renewal request and assign
///    `UUEmptyAuthorization()` before
///    executing it.
///
/// Example (skip auth on a login request):
///
/// ```swift
/// open override func renewApiAuthorization() async -> UURenewAuthorizationResponse
/// {
///     let request = UUHttpRequest(url: loginUrl, method: .post, body: credentialsBody)
///     request.authorization = UUEmptyAuthorization()
///     let response = await executeWithoutAuthorizationRenewal(request)
///     // Parse tokens and update the API's authorization provider ...
///     return UURenewAuthorizationResponse(didAttempt: true, error: response.httpError)
/// }
/// ```
///
/// ``UURemoteApi/prepareRequest(_:)`` does not replace a request's existing
/// ``UUHttpRequest/authorization``, so the empty authorization remains in effect for that
/// request only.
///
/// - SeeAlso: ``UUHttpAuthorization``
/// - SeeAlso: ``UURemoteApi/renewApiAuthorization()``
/// - SeeAlso: ``UURemoteApi/executeWithoutAuthorizationRenewal(_:)``
/// - SeeAlso: ``UURemoteApi/authorizationProvider``
/// - SeeAlso: ``UUHttpRequest/authorization``
open class UUEmptyAuthorization: UUHttpAuthorization, @unchecked Sendable
{
    /// Always returns `nil`, indicating that no credential string should be sent.
    open override func formatAuthorization() -> String?
    {
        return nil
    }

    /// Intentionally does nothing; no `Authorization` header is added or modified.
    open override func attachAuthorization(_ request: UUHttpRequest)
    {
        // Do nothing
    }
}
