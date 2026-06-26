//
//  UUPKCE.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/26/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import UUSwiftCore

public struct UUPKCE
{
    private static let minVerifierByteLength = 32
    private static let maxVerifierByteLength = 96
    
    public let challengeMethod = "S256"
    public let codeVerifier: String
    public let codeChallenge: String
    
    public static func generate(_ verifierLength: Int? = nil) -> UUPKCE
    {
        // Generate PKCE challenge per RFC 7636
        //
        // code_verifier is 43-128 characters, ALPHA / DIGIT / "-" / "." / "_" / "~"
        //
        // From the RFC:
        // It is RECOMMENDED that the output of a suitable random number generator be used to create a 32-octet sequence.
        // The octet sequence is then base64url-encoded to produce a 43-octet URL safe string to use as the code verifier.
        //
        // If the caller specifies a verifierLength, use that, otherwise generate a byte array that will
        // produce a base64 url encoded result within the 43-128 character limit.
        //
        // If the input is out of bounds, just clamp is so we can always produce a valid PKCE input
        let size = (verifierLength ?? UURandom.int(min: Self.minVerifierByteLength, max: Self.maxVerifierByteLength)).uuClamp(min: Self.minVerifierByteLength, max: Self.maxVerifierByteLength)
        let bytes = UURandom.bytes(length: size)
        let verifier = bytes.uuBase64UrlEncode()
        
        // From the RFC:
        // code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))
        //
        // We use UTF8 here because there is no ascii equivalent.  This is ok because for base64 encoding, ascii and utf8 are the same.
        let challenge = Data(verifier.utf8).uuSha256().uuBase64UrlEncode()
        
        let pkce = UUPKCE(
            codeVerifier: verifier,
            codeChallenge: challenge
        )
        
        return pkce
    }
}
