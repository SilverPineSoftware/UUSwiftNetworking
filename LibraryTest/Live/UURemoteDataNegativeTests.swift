//
//  UURemoteDataNegativeTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 09/01/22.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

private final class FetchCounter: @unchecked Sendable
{
    private let lock = NSLock()
    private var _started = 0
    private var _ended = 0

    var started: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return _started
    }

    var ended: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return _ended
    }

    func recordStart()
    {
        lock.lock()
        _started += 1
        lock.unlock()
    }

    func recordEnd()
    {
        lock.lock()
        _ended += 1
        lock.unlock()
    }
}

class UURemoteDataNegativeTests: BaseOnlineTest
{
    override func setUpWithError() throws
    {
        try super.setUpWithError()
    }

    override func setUp() async throws
    {
        try await super.setUp()

        await remoteDataForTest.dataCache.clearCache()
        remoteDataForTest.clearMemoryCache()
        remoteDataForTest.maxActiveRequests = 50
    }

    open var remoteDataForTest: UURemoteData
    {
        let api = UURemoteData.shared
        api.networkTimeout = 300.0
        return api
    }

    func test_recursiveErrorDownload() async
    {
        let count = 10_000
        let api = remoteDataForTest

        let key = "https://dddkj112nrsr4.cloudfront.net/media/jr/dx/jrdxK9/item/BYZkn9/39c1af41c5e94885bdfb9ef90536e59d.jpg"

        let exp = expectation(description: #function)
        exp.expectedFulfillmentCount = count

        let counter = FetchCounter()

        for i in 0..<count
        {
            counter.recordStart()

            _ = await api.data(for: key, remoteLoadCompletion:
            { _, _ in
                counter.recordEnd()
                exp.fulfill()
            })
        }

        await fulfillment(of: [exp], timeout: api.networkTimeout)

        XCTAssertEqual(counter.started, count)
        XCTAssertEqual(counter.ended, count)
    }

    func test_recursiveBadUrlFetch() async
    {
        let maxAttempts = 10
        let url = Constants.nonExistantHostUrl
        let counter = FetchCounter()

        let exp = expectation(description: #function)

        await doFetchFromBadUrl(
            url: url,
            count: 0,
            maxAttempts: maxAttempts,
            counter: counter)
        {
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: remoteDataForTest.networkTimeout)

        XCTAssertEqual(counter.started, maxAttempts)
        XCTAssertEqual(counter.ended, maxAttempts)
    }

    private func doFetchFromBadUrl(
        url: String,
        count: Int,
        maxAttempts: Int,
        counter: FetchCounter,
        completion: @escaping @Sendable () -> Void) async
    {
        guard count < maxAttempts else
        {
            completion()
            return
        }

        counter.recordStart()

        let data = await remoteDataForTest.data(for: url, remoteLoadCompletion:
        { remoteDataOpt, remoteErrOpt in
            counter.recordEnd()
            XCTAssertNil(remoteDataOpt)
            XCTAssertNotNil(remoteErrOpt)

            await self.doFetchFromBadUrl(
                url: url,
                count: count + 1,
                maxAttempts: maxAttempts,
                counter: counter,
                completion: completion)
        })

        XCTAssertNil(data)
    }
}
