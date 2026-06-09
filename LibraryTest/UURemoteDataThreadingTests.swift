//
//  UURemoteDataThreadingTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/8/26.
//

import XCTest
import UUSwiftCore
@testable import UUSwiftNetworking

final class UURemoteDataThreadingTests: XCTestCase
{
    private let testKey = "https://example.com/threading-test.bin"

    override func setUp() async throws
    {
        try await super.setUp()
        await UURemoteData.shared.dataCache.clearCache()
        UURemoteData.shared.clearMemoryCache()
        UURemoteData.shared.cacheQueue = DispatchQueue(
            label: "com.silverpine.uu.test.cache",
            qos: .utility)
    }

    func test_memoryCacheReturnsDataWithoutDiskRead() async
    {
        let api = UURemoteData.shared
        let payload = Data([0x01, 0x02, 0x03, 0x04])

        await api.save(data: payload, key: testKey)

        let cached = await api.data(for: testKey)
        XCTAssertEqual(cached, payload)
    }

    func test_callbackQueue_deliversOnConfiguredQueue() async
    {
        let api = UURemoteData.shared
        api.callbackQueue = DispatchQueue(label: "com.silverpine.uu.test.callback", qos: .utility)

        let badKey = "http://this.is.a.fake.url/non_existent_threading.jpg"
        let exp = expectation(description: #function)

        final class CallbackThreadBox: @unchecked Sendable
        {
            var isMainThread: Bool?
        }

        let box = CallbackThreadBox()

        _ = await api.data(for: badKey, remoteLoadCompletion:
        { _, _ in
            box.isMainThread = Thread.isMainThread
            exp.fulfill()
        })

        await fulfillment(of: [exp], timeout: api.networkTimeout)

        XCTAssertEqual(box.isMainThread, false)
    }

    func test_notificationQueue_postsOnConfiguredQueue() async
    {
        let api = UURemoteData.shared
        api.notificationQueue = DispatchQueue(label: "com.silverpine.uu.test.notification", qos: .utility)

        let badKey = "http://this.is.a.fake.url/non_existent_notification.jpg"

        final class NotificationThreadBox: @unchecked Sendable
        {
            var isMainThread: Bool?
        }

        let box = NotificationThreadBox()
        let exp = expectation(description: #function)

        let observer = NotificationCenter.default.addObserver(
            forName: UURemoteData.Notifications.DataDownloadFailed,
            object: nil,
            queue: nil)
        { notification in
            guard notification.uuRemoteDataPath == badKey else
            {
                return
            }

            box.isMainThread = Thread.isMainThread
            exp.fulfill()
        }

        defer { NotificationCenter.default.removeObserver(observer) }

        _ = await api.data(for: badKey)

        await fulfillment(of: [exp], timeout: api.networkTimeout)

        XCTAssertEqual(box.isMainThread, false)
    }

    func test_isDownloadActive_isAsync() async
    {
        let api = UURemoteData.shared
        let active = await api.isDownloadActive(for: testKey)
        XCTAssertFalse(active)
    }
}
