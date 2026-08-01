//
//  UUHttpAuthorization.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/22/21.
//

import Foundation

/// Formats credentials for the HTTP [Authorization](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Authorization)
/// request header.
///
/// ``UUHttpAuthorization`` is a lightweight model object. Fill it with credentials, assign it to
/// ``UUHttpRequest/authorization``, and ``UUHttpRequest`` will attach the formatted header while
/// building the outbound ``URLRequest``.
///
/// The header is written as:
///
/// ```
/// Authorization: <scheme> <credentials>
/// ```
///
/// Examples: `Bearer eyJhbGciOiJIUzI1NiIs...`, `Basic dXNlcjpwYXNz`.
///
/// **Per-request:** set ``UUHttpRequest/authorization`` on a single request.
///
/// If ``formatAuthorization()`` returns `nil`, no `Authorization` header is added.
///
/// Example (Bearer token):
///
/// ```swift
/// let request = UUHttpRequest(url: "https://api.example.com/v1/items")
/// request.authorization = UUHttpAuthorization(
///     scheme: "Bearer",
///     authorization: accessToken
/// )
/// ```
///
/// Override ``formatAuthorization()`` for alternate credential formatting (see ``UUBasicAuthorization``).
///
/// - SeeAlso: ``UUBasicAuthorization``
/// - SeeAlso: ``UUHttpRequest/authorization``
open class UUHttpAuthorization: @unchecked Sendable
{
    /// Authentication scheme, the first token in the header value (for example `"Bearer"` or `"Basic"`).
    /// Must not include a trailing space.
    public var scheme: String = ""

    /// Credential string used by the default ``formatAuthorization()`` implementation.
    /// Subclasses may ignore this property and compute the value in ``formatAuthorization()`` instead.
    public var authorization: String? = nil
    
    /// Creates an authorization model with a fixed scheme and optional static credential.
    ///
    /// - Parameters:
    ///   - scheme: Authentication scheme prepended to the credential (default `"Bearer"`).
    ///   - authorization: Static credential returned by the default ``formatAuthorization()`` implementation.
    public init(scheme: String = "Bearer", authorization: String? = nil)
    {
        self.scheme = scheme
        self.authorization = authorization
    }
    
    /// Returns the credential portion of the `Authorization` header (the text after ``scheme``).
    ///
    /// The default implementation returns ``authorization``.
    ///
    /// - Returns: Encoded credentials, or `nil` to omit the header for this request.
    open func formatAuthorization() -> String?
    {
        return authorization
    }

    /// Returns the complete `Authorization` header value, including the authentication scheme.
    open func formatHeaderValue() -> String?
    {
        guard let auth = formatAuthorization() else
        {
            return nil
        }
        
        return "\(scheme) \(auth)"
    }

    /// Adds `Authorization: <scheme> <credentials>` to ``UUHttpRequest/headerFields`` when
    /// ``formatAuthorization()`` returns a non-`nil` value.
    ///
    /// - Parameter request: The outbound request; header fields are updated in place.
    open func attachAuthorization(_ request: UUHttpRequest)
    {
        if let auth = formatHeaderValue()
        {
            request.headerFields[UUHttpHeader.authorization] = auth
        }
    }
}
