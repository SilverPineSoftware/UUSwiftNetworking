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
/// Both ``executeRequest(_:)`` and ``executeCodableRequest(_:)`` follow the same pattern:
///
/// 1. **Proactive renewal** — if ``isApiAuthorizationNeeded()`` is `true`, ``renewApiAuthorization()``
///    runs before the request is sent.
/// 2. **Prepare** — ``prepareRequest(_:)`` assigns ``authorizationProvider`` to the request when
///    the request does not already have one.
/// 3. **Execute** — the request is sent through ``session``.
/// 4. **Reactive renewal** — if the response error satisfies ``shouldRenewApiAuthorization(_:)``,
///    renewal runs once more and the request is retried when `didAttempt` is `true`.
///
/// ## Subclassing
///
/// Override ``renewApiAuthorization()``, ``isApiAuthorizationNeeded()``, and optionally
/// ``shouldRenewApiAuthorization(_:)`` and ``prepareRequest(_:)`` for custom API behavior.
/// Override ``executeRequest(_:)`` only when the full authorization wrapper must change.
open class UURemoteApi
{
    /// The HTTP session used to perform network requests.
    ///
    /// Defaults to a new ``UUHttpSession`` instance. Assign a custom session for testing or
    /// per-API configuration such as timeouts or protocol classes.
    public var session: UUHttpSession = UUHttpSession()

    /// The authorization provider applied to requests that do not specify their own.
    ///
    /// Used by ``prepareRequest(_:)``. Set this once on the API instance rather than on every
    /// individual ``UUHttpRequest``.
    public var authorizationProvider: UUHttpAuthorizationProvider? = nil

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
    open func executeRequest(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        let renewResult = await renewApiAuthorizationIfNeeded()
        if let authorizationRenewalError = renewResult.error
        {
            return UUHttpResponse(request: request, response: nil, error: authorizationRenewalError)
        }

        await prepareRequest(request)
        var response = await session.executeRequest(request)
        if let err = response.httpError, await shouldRenewApiAuthorization(err)
        {
            let innerRenewResult = await internalRenewApiAuthorization()
            if let innerAuthorizationRenewalError = innerRenewResult.error
            {
                return UUHttpResponse(request: request, response: nil, error: innerAuthorizationRenewalError)
            }

            if (innerRenewResult.didAttempt)
            {
                // Prepare again (assuming authorization has changed)
                await prepareRequest(request)
                response = await session.executeRequest(request)
            }
        }

        return response
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
    }

    /// Executes a typed codable request with proactive and reactive authorization handling.
    ///
    /// Mirrors the authorization behavior of ``executeRequest(_:)`` but returns a
    /// `Result<SuccessType, Error>` parsed by the request's response handler.
    ///
    /// - Parameters:
    ///   - request: A codable HTTP request describing the expected success and error types.
    /// - Returns: `.success` with the parsed model, or `.failure` with a network, parse, or
    ///   authorization renewal error.
    open func executeCodableRequest<SuccessType: Codable, ErrorType: Codable>(
        _ request: UUCodableHttpRequest<SuccessType, ErrorType>) async -> Result<SuccessType, Error>
    {
        let renewResult = await renewApiAuthorizationIfNeeded()
        if let authorizationRenewalError = renewResult.error
        {
            return .failure(authorizationRenewalError)
        }

        await prepareRequest(request)
        var result = await session.executeCodableRequest(request)
        switch (result)
        {
            case .success(let success):
                return .success(success)

            case .failure(let error):

                if (await shouldRenewApiAuthorization(error))
                {
                    let innerRenewResult = await internalRenewApiAuthorization()
                    if let innerAuthorizationRenewalError = innerRenewResult.error
                    {
                        return .failure(innerAuthorizationRenewalError)
                    }

                    if (innerRenewResult.didAttempt)
                    {
                        // Prepare again (assuming authorization has changed)
                        await prepareRequest(request)
                        result = await session.executeCodableRequest(request)
                    }
                }

            return result
        }
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
    /// - Returns: A response indicating whether renewal was attempted and any error that occurred.
    ///   The default implementation returns `didAttempt: false` with no error.
    open func renewApiAuthorization() async -> UURenewAuthorizationResponse
    {
        return UURenewAuthorizationResponse(didAttempt: false, error: nil)
    }

    /// Returns whether API authorization should be renewed before the next request.
    ///
    /// Called proactively at the start of ``executeRequest(_:)`` and ``executeCodableRequest(_:)``.
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

        let result = await renewApiAuthorization()
        return await renewalGate.finish(result)
    }
}
