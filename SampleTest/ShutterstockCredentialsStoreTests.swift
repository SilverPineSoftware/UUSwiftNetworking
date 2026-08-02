//
//  ShutterstockCredentialsStoreTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 8/1/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import XCTest
import UUSwiftCore
@testable import UUSwiftNetworkingSample

final class ShutterstockCredentialsStoreTests: XCTestCase
{
    func test_loadCredentials_returnsEmptyCredentialsWhenKeysAreMissing() async throws
    {
        let keychain = MockShutterstockKeychain(readResults: [
            "shutterstock_api.client_key": .failure(.notFound),
            "shutterstock_api.client_secret": .failure(.notFound),
        ])
        let store = UUShutterstockCredentialsStore(keychain: keychain)
        
        let credentials = try await store.loadCredentials().get()
        
        XCTAssertEqual(credentials, .empty)
    }
    
    func test_loadCredentials_returnsErrorWhenKeychainReadFails() async
    {
        let keychain = MockShutterstockKeychain(readResults: [
            "shutterstock_api.client_key": .failure(.transformFailed(underlying: nil)),
            "shutterstock_api.client_secret": .success(Data("secret".utf8)),
        ])
        let store = UUShutterstockCredentialsStore(keychain: keychain)
        
        let result = await store.loadCredentials()
        
        guard case .failure(let error as UUKeychainError) = result else
        {
            XCTFail("Expected keychain error, got \(result)")
            return
        }
        
        XCTAssertEqual(error, .transformFailed(underlying: nil))
    }
    
    func test_saveCredentials_trimsAndWritesBothValues() async
    {
        let keychain = MockShutterstockKeychain()
        let store = UUShutterstockCredentialsStore(keychain: keychain)
        
        let error = await store.saveCredentials(ShutterstockCredentials(
            clientKey: " key ",
            clientSecret: "\nsecret\t"))
        
        XCTAssertNil(error)
        XCTAssertEqual(keychain.writtenStrings["shutterstock_api.client_key"], "key")
        XCTAssertEqual(keychain.writtenStrings["shutterstock_api.client_secret"], "secret")
    }
}

private final class MockShutterstockKeychain: UUKeychain, @unchecked Sendable
{
    let serviceIdentifier = "com.silverpine.uu.networking.tests.shutterstock"
    let accessGroup: String? = nil
    
    var readResults: [String: Result<Data, UUKeychainError>]
    var writtenStrings: [String: String] = [:]
    var clearedKeys: [String] = []
    
    init(readResults: [String: Result<Data, UUKeychainError>] = [:])
    {
        self.readResults = readResults
    }
    
    func read(key: String) async -> Result<Data, UUKeychainError>
    {
        return readResults[key] ?? .failure(.notFound)
    }
    
    func write(key: String, accessLevel: UUKeychainAccessLevel, data: Data) async -> UUKeychainError?
    {
        writtenStrings[key] = String(data: data, encoding: .utf8)
        return nil
    }
    
    func clear(key: String) async -> UUKeychainError?
    {
        clearedKeys.append(key)
        return nil
    }
}
