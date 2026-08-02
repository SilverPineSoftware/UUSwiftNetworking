//
//  ShutterstockCredentialsStore.swift
//  Sample
//
//  Created by Ryan DeVore on 7/11/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import UUSwiftCore

struct ShutterstockCredentials: Equatable, Sendable
{
    let clientKey: String
    let clientSecret: String
    
    static let empty = ShutterstockCredentials(clientKey: "", clientSecret: "")
    
    var isComplete: Bool
    {
        !clientKey.isEmpty && !clientSecret.isEmpty
    }
}

protocol ShutterstockCredentialsStore: Sendable
{
    func loadCredentials() async -> Result<ShutterstockCredentials, Error>
    func saveCredentials(_ credentials: ShutterstockCredentials) async -> Error?
    func clearCredentials() async -> Error?
}

final class UUShutterstockCredentialsStore: ShutterstockCredentialsStore, @unchecked Sendable
{
    private static let clientKeyKey = "shutterstock_api.client_key"
    private static let clientSecretKey = "shutterstock_api.client_secret"
    
    private let keychain: any UUKeychain
    private let accessLevel: UUKeychainAccessLevel
    
    init(
        keychain: any UUKeychain = UUEncryptedKeychain(
            serviceIdentifier: "com.silverpine.uu.networking.sample.shutterstock",
            crypto: UUSecurity.crypto),
        accessLevel: UUKeychainAccessLevel = .afterFirstUnlockThisDeviceOnly)
    {
        self.keychain = keychain
        self.accessLevel = accessLevel
    }
    
    func loadCredentials() async -> Result<ShutterstockCredentials, Error>
    {
        let clientKeyResult = await loadString(key: Self.clientKeyKey)
        let clientSecretResult = await loadString(key: Self.clientSecretKey)
        
        switch (clientKeyResult, clientSecretResult)
        {
            case (.success(let clientKey), .success(let clientSecret)):
                return .success(ShutterstockCredentials(
                    clientKey: clientKey,
                    clientSecret: clientSecret))
            
            case (.failure(let error), _),
                 (_, .failure(let error)):
                return .failure(error)
        }
    }
    
    func saveCredentials(_ credentials: ShutterstockCredentials) async -> Error?
    {
        if let error = await saveString(credentials.clientKey, key: Self.clientKeyKey)
        {
            return error
        }
        
        if let error = await saveString(credentials.clientSecret, key: Self.clientSecretKey)
        {
            return error
        }
        
        return nil
    }
    
    func clearCredentials() async -> Error?
    {
        if let error = await keychain.clear(key: Self.clientKeyKey)
        {
            return error
        }
        
        if let error = await keychain.clear(key: Self.clientSecretKey)
        {
            return error
        }
        
        return nil
    }
    
    private func saveString(_ value: String, key: String) async -> Error?
    {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedValue.isEmpty else
        {
            return await keychain.clear(key: key)
        }
        
        return await keychain.writeString(
            key: key,
            accessLevel: accessLevel,
            string: trimmedValue)
    }
    
    private func loadString(key: String) async -> Result<String, Error>
    {
        switch await keychain.readString(key: key)
        {
            case .success(let value):
                return .success(value)
            
            case .failure(.notFound):
                return .success("")
            
            case .failure(let error):
                return .failure(error)
        }
    }
}
