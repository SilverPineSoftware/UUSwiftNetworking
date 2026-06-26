//
//  UUPKCE.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/26/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  Proof Key for Code Exchange (PKCE) helpers for OAuth 2.0 authorization requests (RFC 7636).
//

import Foundation
import UUSwiftCore

/// PKCE parameters for the authorization request and token redemption steps.
///
/// Generates an unpadded Base64URL `code_verifier` and an S256 `code_challenge` suitable for
/// `code_challenge` / `code_challenge_method` query parameters and later `code_verifier` submission.
public struct UUPKCE
{
    private static let sha256ChallengeMethod = "S256"
    private static let minVerifierByteLength = 32
    private static let maxVerifierByteLength = 96

    /// The PKCE code challenge method (`S256`).
    public let challengeMethod = sha256ChallengeMethod

    /// The original high-entropy secret. Send this to the token endpoint, not the challenge.
    public let codeVerifier: String

    /// The S256 challenge derived from ``codeVerifier``. Send this on the authorize request.
    public let codeChallenge: String
    
    /// Creates PKCE values from an existing verifier/challenge pair.
    public init(codeVerifier: String, codeChallenge: String)
    {
        self.codeVerifier = codeVerifier
        self.codeChallenge = codeChallenge
    }

    /// Generates a new PKCE pair using secure random bytes.
    ///
    /// - Parameter verifierLength: Optional raw byte length before Base64URL encoding. Values are
    ///   clamped to 32...96 bytes so the encoded verifier stays within the RFC 7636 limit of
    ///   43...128 characters.
    /// - Returns: A new ``UUPKCE`` with ``challengeMethod`` `S256`.
    public static func generate(_ verifierLength: Int? = nil) -> UUPKCE
    {
        let size = (verifierLength ?? UURandom.int(min: minVerifierByteLength, max: maxVerifierByteLength))
            .uuClamp(min: minVerifierByteLength, max: maxVerifierByteLength)
        
        let verifier = verifier(from: UURandom.bytes(length: size))

        return UUPKCE(
            codeVerifier: verifier,
            codeChallenge: s256Challenge(from: verifier)
        )
    }

    /// Encodes random bytes as an unpadded Base64URL code verifier.
    public static func verifier(from bytes: Data) -> String
    {
        return bytes.uuBase64UrlEncode()
    }

    /// Computes the S256 code challenge for a verifier string.
    ///
    /// Applies `BASE64URL(SHA256(UTF8(verifier)))` per RFC 7636.
    public static func s256Challenge(from verifier: String) -> String
    {
        return Data(verifier.utf8).uuSha256().uuBase64UrlEncode()
    }
}
