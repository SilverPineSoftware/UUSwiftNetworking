//
//  UURemoteDataConcurrent_1000.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/27/21.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

class UURemoteDataConcurrent_1000: UURemoteDataTests
{
    override var concurrentDownloadCount: Int
    {
        return 1000
    }
}
