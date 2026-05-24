//
//  UURemoteDataConcurrent_100.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/27/21.
//

#if _REFACTOR_IN_PROGRESS_IGNORE_ME

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

class UURemoteDataConcurrent_100: UURemoteDataTests
{
    override var concurrentDownloadCount: Int
    {
        return 100
    }
}

#endif
