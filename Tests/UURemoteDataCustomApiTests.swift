//
//  UURemoteDataTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/18/21.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

class UURemoteDataCustomTests: UURemoteDataTests
{
    override open var remoteDataForTest: UURemoteData
    {
        return UURemoteData(dataCache: UUDataCache.shared, remoteApi: CustomRemoteApi())
    }
}

fileprivate class CustomRemoteApi: UURemoteApi
{
    override func isApiAuthorizationNeeded(_ completion: @escaping (Bool) -> ())
    {
        completion(true)
    }
    
    override func renewApiAuthorization(_ completion: @escaping (Error?) -> ())
    {
        completion(nil)
    }
}
