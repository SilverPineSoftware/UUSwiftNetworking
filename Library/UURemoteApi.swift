//
//  UURemoteApi.swift
//  Useful Utilities - Base class for RESTful api's
//
//
//  Created by Ryan DeVore on 10/20/21.
//

import Foundation

/// A base class for RESTful API clients with proactive and reactive authorization renewal.
///
/// `UURemoteApi` wraps ``UUHttpSession`` and adds an authorization lifecycle around every request.
/// Subclasses override renewal hooks to fetch tokens, refresh credentials, or perform login flows.
/// Concurrent callers share a single in-flight renewal; late waiters receive the same result.
///
/// ## Request flow
///
/// Both ``execute(_:)`` and ``executeTyped(_:)`` follow the same pattern:
///
/// 1. **Proactive renewal** — if ``isApiAuthorizationNeeded()`` is `true`, ``renewApiAuthorization()``
///    runs before the request is sent.
/// 2. **Send** — ``executeWithoutAuthorizationRenewal(_:)`` or
///    ``executeTypedWithoutAuthorizationRenewal(_:)`` applies shared configuration via
///    ``prepareRequest(_:)`` and sends the request through ``session``.
/// 3. **Reactive renewal** — if the response error satisfies ``shouldRenewApiAuthorization(_:)``,
///    renewal runs once more and the request is retried when `didAttempt` is `true`.
///
/// For login, token refresh, and other calls made *inside* ``renewApiAuthorization()``, prefer
/// ``executeWithoutAuthorizationRenewal(_:)`` or ``executeTypedWithoutAuthorizationRenewal(_:)``.
/// If ``execute(_:)`` or ``executeTyped(_:)`` is called from within ``renewApiAuthorization()`` on
/// the same task, renewal is skipped automatically so the call cannot deadlock on the renewal gate.
///
/// ## Re-entrancy
///
/// A `@TaskLocal` flag is set for the duration of ``renewApiAuthorization()``. Calls to
/// ``execute(_:)`` or ``executeTyped(_:)`` made on that same task are downgraded to
/// ``executeWithoutAuthorizationRenewal(_:)`` or ``executeTypedWithoutAuthorizationRenewal(_:)``.
/// Concurrent ``execute(_:)`` calls from other tasks are unaffected and still coalesce on the
/// renewal gate.
///
/// ## Subclassing
///
/// Override ``renewApiAuthorization()``, ``isApiAuthorizationNeeded()``, and optionally
/// ``shouldRenewApiAuthorization(_:)`` and ``prepareRequest(_:)`` for custom API behavior.
/// Override ``execute(_:)`` only when the full authorization wrapper must change.
open class UURemoteApi
{
    /// The HTTP session used to perform network requests.
    ///
    /// Defaults to a new ``UUHttpSession`` instance. Assign a custom session for testing or
    /// per-API configuration such as timeouts or protocol classes.
    public var session: UUHttpSession = UUHttpSession()
    
    /// The authorization provider applied to requests that do not define their own.
    ///
    /// ``prepareRequest(_:)`` assigns this value to
    /// ``authorizationProvider`` only when the request's provider is `nil`.
    /// Requests with an explicit provider are left unchanged.
    ///
    /// Typical values include ``UUBasicAuthorizationProvider`` or a custom
    /// ``UUHttpAuthorizationProvider`` subclass that attaches bearer tokens or signed headers.
    public var authorizationProvider: UUHttpAuthorizationProvider? = nil

    /// Shared request defaults for this API client.
    ///
    /// ``prepareRequest(_:)`` applies ``UURemoteApiConfig/authorizationProvider`` and
    /// ``UURemoteApiConfig/networkTimeout`` to each ``UUHttpRequest`` before it is sent through
    /// ``session``. Set this once on the API instance instead of configuring every request
    /// manually.
    ///
    /// - Note: Requests that already have an ``UUHttpRequest/authorizationProvider`` keep their
    ///   existing provider; only `nil` providers are populated from config.
    public var config = UURemoteApiConfig()
    
    /// Creates a remote API with default session and no authorization provider.
    public init()
    {

    }

    /// Executes an HTTP request with proactive and reactive authorization handling.
    ///
    /// Before sending, checks whether API authorization renewal is needed and performs renewal
    /// when ``isApiAuthorizationNeeded()`` returns `true`. If the response indicates that
    /// authorization is required (see ``shouldRenewApiAuthorization(_:)``), renewal is attempted
    /// again and the original request is retried once when renewal reports `didAttempt`.
    ///
    /// - Parameter request: The request to execute. Its ``UUHttpRequest/authorizationProvider``
    ///   is populated from ``authorizationProvider`` when nil.
    /// - Returns: The HTTP response. When proactive renewal fails, the response contains the
    ///   renewal error and no network call is made. When reactive renewal fails, the renewal
    ///   error is returned instead of the original authorization error.
    ///
    /// - Note: When called from within ``renewApiAuthorization()`` on the same task, behaves like
    ///   ``executeWithoutAuthorizationRenewal(_:)`` to avoid re-entering the authorization lifecycle.
    open func execute(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        if RenewalContext.isActive
        {
            return await executeWithoutAuthorizationRenewal(request)
        }

        return await executeWithAuthorizationRenewal(request)
    }

    /// Prepares a request for execution by applying shared API configuration.
    ///
    /// The default implementation assigns ``authorizationProvider`` to
    /// ``UUHttpRequest/authorizationProvider`` when the request's provider is `nil`.
    /// Override to add headers, base URLs, or other per-request setup.
    ///
    /// - Parameter request: The request about to be executed.
    open func prepareRequest(_ request: UUHttpRequest) async
    {
        if (request.authorizationProvider == nil)
        {
            request.authorizationProvider = self.authorizationProvider
        }
        
        request.timeout = self.config.networkTimeout
    }
    
    /// Sends a single HTTP request without proactive or reactive authorization renewal.
    ///
    /// Calls ``prepareRequest(_:)`` then ``UUHttpSession/execute(_:)``. Unlike ``execute(_:)``, this
    /// method does not perform proactive renewal, reactive renewal, or automatic retry.
    ///
    /// Use this inside ``renewApiAuthorization()`` for login, token refresh, and other requests that
    /// must not re-enter the authorization lifecycle. Pair with ``UUEmptyAuthorizationProvider`` on
    /// the request when the renewal call should not attach ``UURemoteApiConfig/authorizationProvider``
    /// credentials.
    ///
    /// Example:
    ///
    /// ```swift
    /// open override func renewApiAuthorization() async -> UURenewAuthorizationResponse
    /// {
    ///     let request = UUHttpRequest(url: tokenUrl, method: .post, body: credentialsBody)
    ///     request.authorizationProvider = UUEmptyAuthorizationProvider()
    ///     let response = await executeWithoutAuthorizationRenewal(request)
    ///     // Parse tokens and update config.authorizationProvider ...
    ///     return UURenewAuthorizationResponse(didAttempt: true, error: response.httpError)
    /// }
    /// ```
    ///
    /// - Parameter request: The request to prepare and send.
    /// - Returns: The HTTP response from ``session``.
    ///
    /// - SeeAlso: ``execute(_:)``
    /// - SeeAlso: ``executeTypedWithoutAuthorizationRenewal(_:)``
    /// - SeeAlso: ``UUEmptyAuthorizationProvider``
    open func executeWithoutAuthorizationRenewal(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        await prepareRequest(request)
        return await session.execute(request)
    }

    /// Executes a typed codable request with proactive and reactive authorization handling.
    ///
    /// Mirrors the authorization behavior of ``execute(_:)`` but returns a
    /// `Result<SuccessType, Error>` parsed by the request's response handler.
    ///
    /// - Parameters:
    ///   - request: A codable HTTP request describing the expected success and error types.
    /// - Returns: `.success` with the parsed model, or `.failure` with a network, parse, or
    ///   authorization renewal error.
    ///
    /// - Note: When called from within ``renewApiAuthorization()`` on the same task, behaves like
    ///   ``executeTypedWithoutAuthorizationRenewal(_:)`` to avoid re-entering the authorization lifecycle.
    open func executeTyped<SuccessType: Codable, ErrorType: Codable>(
        _ request: UUCodableHttpRequest<SuccessType, ErrorType>) async -> Result<SuccessType, Error>
    {
        if RenewalContext.isActive
        {
            return await executeTypedWithoutAuthorizationRenewal(request)
        }

        return await executeTypedWithAuthorizationRenewal(request)
    }
    
    /// Sends a single typed HTTP request without proactive or reactive authorization renewal.
    ///
    /// Calls ``prepareRequest(_:)`` then ``UUHttpSession/executeTyped(_:)``. Unlike ``executeTyped(_:)``,
    /// this method does not perform proactive renewal, reactive renewal, or automatic retry.
    ///
    /// Use this inside ``renewApiAuthorization()`` when the renewal flow expects a parsed codable
    /// response. Pair with ``UUEmptyAuthorizationProvider`` when the renewal request should not
    /// attach ``UURemoteApiConfig/authorizationProvider`` credentials.
    ///
    /// - Parameter request: A codable HTTP request describing the expected success and error types.
    /// - Returns: `.success` with the parsed model, or `.failure` with a network or parse error.
    ///
    /// - SeeAlso: ``executeTyped(_:)``
    /// - SeeAlso: ``executeWithoutAuthorizationRenewal(_:)``
    /// - SeeAlso: ``UUEmptyAuthorizationProvider``
    open func executeTypedWithoutAuthorizationRenewal<SuccessType: Codable, ErrorType: Codable>(
        _ request: UUCodableHttpRequest<SuccessType, ErrorType>) async -> Result<SuccessType, Error>
    {
        await prepareRequest(request)
        return await session.executeTyped(request)
    }

    /// Performs API authorization renewal.
    ///
    /// Called when proactive or reactive renewal is required. Typical implementations fetch a
    /// new JWT, refresh OAuth tokens, or perform a login request and update
    /// ``authorizationProvider``.
    ///
    /// Concurrent callers are coalesced: only one renewal runs at a time and all waiters receive
    /// the same ``UURenewAuthorizationResponse``.
    ///
    /// A `@TaskLocal` flag is active for the duration of this method. ``execute(_:)`` and
    /// ``executeTyped(_:)`` called on the same task during renewal skip proactive and reactive
    /// renewal automatically. Prefer ``executeWithoutAuthorizationRenewal(_:)`` for renewal HTTP
    /// calls so intent is explicit.
    ///
    /// - Returns: A response indicating whether renewal was attempted and any error that occurred.
    ///   The default implementation returns `didAttempt: false` with no error.
    open func renewApiAuthorization() async -> UURenewAuthorizationResponse
    {
        return UURenewAuthorizationResponse(didAttempt: false, error: nil)
    }

    /// Returns whether API authorization should be renewed before the next request.
    ///
    /// Called proactively at the start of ``execute(_:)`` and ``executeTyped(_:)``.
    /// Typical implementations inspect token expiration on ``authorizationProvider``.
    ///
    /// - Returns: `true` when renewal should run before sending a request. The default is `false`.
    open func isApiAuthorizationNeeded() async -> Bool
    {
        return false
    }

    /// Returns whether an error from a completed request should trigger reactive renewal.
    ///
    /// Called after a request fails. When this returns `true`, ``renewApiAuthorization()`` runs
    /// and the original request may be retried.
    ///
    /// - Parameter error: The error returned from the HTTP session or response handler.
    /// - Returns: `true` when the error indicates missing or expired credentials. The default
    ///   returns `true` for ``UUHttpSessionError/authorizationNeeded``.
    open func shouldRenewApiAuthorization(_ error: Error) async -> Bool
    {
        guard let errorCode = error.uuHttpErrorCode else
        {
            return false
        }

        return (errorCode == .authorizationNeeded)
    }

    /// Cancels all in-flight HTTP tasks on ``session``.
    open func cancelAll()
    {
        session.cancelAll()
    }

    // MARK: Private Implementation

    /// Task-local flag set while ``renewApiAuthorization()`` runs on the current task.
    ///
    /// Child tasks created with `async let` or `Task { }` inherit this value.
    /// ``Task/detached`` does not; use ``executeWithoutAuthorizationRenewal(_:)`` in detached work.
    private enum RenewalContext
    {
        @TaskLocal static var isActive = false
    }

    /// Visible to unit tests via `@testable import`.
    internal static var isAuthorizationRenewalActiveForCurrentTask: Bool
    {
        RenewalContext.isActive
    }

    private func executeWithAuthorizationRenewal(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        let renewResult = await renewApiAuthorizationIfNeeded()
        if let authorizationRenewalError = renewResult.error
        {
            return UUHttpResponse(request: request, response: nil, error: authorizationRenewalError)
        }

        var response = await executeWithoutAuthorizationRenewal(request)
        if let err = response.httpError, await shouldRenewApiAuthorization(err)
        {
            let innerRenewResult = await internalRenewApiAuthorization()
            if let innerAuthorizationRenewalError = innerRenewResult.error
            {
                return UUHttpResponse(request: request, response: nil, error: innerAuthorizationRenewalError)
            }

            if innerRenewResult.didAttempt
            {
                response = await executeWithoutAuthorizationRenewal(request)
            }
        }

        return response
    }

    private func executeTypedWithAuthorizationRenewal<SuccessType: Codable, ErrorType: Codable>(
        _ request: UUCodableHttpRequest<SuccessType, ErrorType>) async -> Result<SuccessType, Error>
    {
        let renewResult = await renewApiAuthorizationIfNeeded()
        if let authorizationRenewalError = renewResult.error
        {
            return .failure(authorizationRenewalError)
        }

        var result = await executeTypedWithoutAuthorizationRenewal(request)
        switch result
        {
            case .success(let success):
                return .success(success)

            case .failure(let error):

                if await shouldRenewApiAuthorization(error)
                {
                    let innerRenewResult = await internalRenewApiAuthorization()
                    if let innerAuthorizationRenewalError = innerRenewResult.error
                    {
                        return .failure(innerAuthorizationRenewalError)
                    }

                    if innerRenewResult.didAttempt
                    {
                        result = await executeTypedWithoutAuthorizationRenewal(request)
                    }
                }

            return result
        }
    }

    private func renewApiAuthorizationIfNeeded() async -> UURenewAuthorizationResponse
    {
        guard await isApiAuthorizationNeeded() else
        {
            return UURenewAuthorizationResponse(didAttempt: false, error: nil)
        }

        return await internalRenewApiAuthorization()
    }

    private let renewalGate = RenewalGate()

    private actor RenewalGate
    {
        private var inFlight = false
        private var waiters: [CheckedContinuation<UURenewAuthorizationResponse, Never>] = []

        /// Returns a coalesced result when renewal is already in flight; `nil` means this caller is the leader.
        func begin() async -> UURenewAuthorizationResponse?
        {
            if inFlight
            {
                return await withCheckedContinuation { waiters.append($0) }
            }
            inFlight = true
            return nil
        }

        func finish(_ result: UURenewAuthorizationResponse) -> UURenewAuthorizationResponse
        {
            inFlight = false
            let pending = waiters
            waiters.removeAll()
            for waiter in pending
            {
                waiter.resume(returning: result)
            }
            return result
        }

        var coalescedWaiterCount: Int
        {
            waiters.count
        }
    }

    /// Visible to unit tests via `@testable import` for renewal coalescing assertions.
    internal func renewalCoalescedWaiterCount() async -> Int
    {
        await renewalGate.coalescedWaiterCount
    }

    private func internalRenewApiAuthorization() async -> UURenewAuthorizationResponse
    {
        if let coalesced = await renewalGate.begin()
        {
            return coalesced
        }

        let result = await RenewalContext.$isActive.withValue(true)
        {
            await renewApiAuthorization()
        }
        return await renewalGate.finish(result)
    }
}
