//
//  UUBasicAuthorization.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/3/26.
//

import Foundation

/// [HTTP Basic authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Authentication#basic_authentication_scheme)
/// for the `Authorization` header.
///
/// Credentials are formed as `username:password`, UTF-8 encoded and Base64-encoded, then sent as:
///
/// ```
/// Authorization: Basic <base64-credentials>
/// ```
///
/// This matches REST APIs that accept a username and password on every request, or an API key as
/// ``userName`` with a shared ``password``.
///
/// ``formatAuthorization()`` returns `nil` (and ``UUHttpAuthorization/attachAuthorization(_:)``
/// adds no header) when ``userName`` or ``password`` is `nil`.
///
/// ``userName`` and ``password`` may be updated at any time; the next request uses the current values.
///
/// Example (single request):
///
/// ```swift
/// request.authorization = UUBasicAuthorization(
///     userName: "my-api-key",
///     password: "my-secret"
/// )
/// ```
///
/// - SeeAlso: [RFC 7617](https://datatracker.ietf.org/doc/html/rfc7617) (HTTP Basic Access Authentication)
/// - SeeAlso: ``UUHttpAuthorization``
/// - SeeAlso: ``UUHttpRequest/authorization``
open class UUBasicAuthorization: UUHttpAuthorization, @unchecked Sendable
{
    /// User name or API key identifier.
    public var userName: String?

    /// Password or secret paired with ``userName``.
    public var password: String?
    
    /// Creates a Basic authorization model for the given credentials.
    ///
    /// - Parameters:
    ///   - userName: User name or API key identifier.
    ///   - password: Password or secret paired with ``userName``.
    public init(userName: String?, password: String?)
    {
        super.init(scheme: "Basic")
        
        self.userName = userName
        self.password = password
    }
    
    /// Returns Base64-encoded `userName:password`, or `nil` if credentials are missing.
    ///
    /// - Returns: Base64 credential payload for the `Basic` scheme, or `nil` to skip the header.
    open override func formatAuthorization() -> String?
    {
        guard let user = userName, let pwd = password else
        {
            return nil
        }
        
        let credential = "\(user):\(pwd)"
        
        return Data(credential.utf8).base64EncodedString()
    }
}
