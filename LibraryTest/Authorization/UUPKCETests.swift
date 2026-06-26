//
//  UUPKCETests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/26/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUPKCETests: XCTestCase
{
    private let ssoDocVerifier = "S0S83yN7QjxqDK2MkP6Q7vP8zXcJ4F9rL2tVb5HqLmN"
    private let ssoDocChallenge = "uccSvGrdzHhwa52zUrpmqfBfPCqnuGwc614S2rmpw80"

    // MARK: - s256Challenge

    func test_s256Challenge_ssoDocumentationVector()
    {
        XCTAssertEqual(UUPKCE.s256Challenge(from: ssoDocVerifier), ssoDocChallenge)
    }

    func test_s256Challenge_produces43CharacterChallenge()
    {
        let challenge = UUPKCE.s256Challenge(from: ssoDocVerifier)
        XCTAssertEqual(challenge.count, 43)
    }

    // MARK: - verifier(from:)

    func test_verifierFromBytes_minimumLength()
    {
        let verifier = UUPKCE.verifier(from: Data(repeating: 0xFB, count: 32))
        XCTAssertEqual(verifier.count, 43)
        XCTAssertTrue(isValidPkceVerifier(verifier))
    }

    func test_verifierFromBytes_maximumLength()
    {
        let verifier = UUPKCE.verifier(from: Data(repeating: 0xAB, count: 96))
        XCTAssertEqual(verifier.count, 128)
        XCTAssertTrue(isValidPkceVerifier(verifier))
    }

    // MARK: - generate

    func test_generate_defaultVerifierLengthIsWithinPkceBounds()
    {
        for _ in 0..<20
        {
            let pkce = UUPKCE.generate()
            assertValidPkcePair(pkce)
        }
    }

    func test_generate_explicit32Bytes_producesMinimumVerifierLength()
    {
        let pkce = UUPKCE.generate(32)
        XCTAssertEqual(pkce.codeVerifier.count, 43)
        assertValidPkcePair(pkce)
    }

    func test_generate_explicit96Bytes_producesMaximumVerifierLength()
    {
        let pkce = UUPKCE.generate(96)
        XCTAssertEqual(pkce.codeVerifier.count, 128)
        assertValidPkcePair(pkce)
    }

    func test_generate_clampsLowVerifierLength()
    {
        let pkce = UUPKCE.generate(0)
        XCTAssertEqual(pkce.codeVerifier.count, 43)
        assertValidPkcePair(pkce)
    }

    func test_generate_clampsHighVerifierLength()
    {
        let pkce = UUPKCE.generate(200)
        XCTAssertEqual(pkce.codeVerifier.count, 128)
        assertValidPkcePair(pkce)
    }

    func test_challengeMethod_isS256()
    {
        XCTAssertEqual(UUPKCE.generate().challengeMethod, "S256")
    }

    // MARK: - helpers

    private func assertValidPkcePair(_ pkce: UUPKCE)
    {
        XCTAssertTrue(isValidPkceVerifier(pkce.codeVerifier))
        XCTAssertEqual(pkce.codeChallenge, UUPKCE.s256Challenge(from: pkce.codeVerifier))
        XCTAssertEqual(pkce.codeChallenge.count, 43)
    }

    private func isValidPkceVerifier(_ value: String) -> Bool
    {
        guard (43...128).contains(value.count) else
        {
            return false
        }

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
