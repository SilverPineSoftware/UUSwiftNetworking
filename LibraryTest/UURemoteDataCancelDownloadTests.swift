//
//  UURemoteDataCancelDownloadTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/12/26.
//

import XCTest
import UUSwiftCore
@testable import UUSwiftNetworking

// MARK: - Shared fixtures

private let cancelTestHost = "https://remote-data-cancel-test.example.com"

private func cancelTestKey(_ suffix: String) -> String
{
    "\(cancelTestHost)/\(suffix).bin"
}

private func cancelTestPayload(_ byte: UInt8 = 0xAB) -> Data
{
    Data([byte, byte + 1, byte + 2])
}

private func cancelTestHttpResponse(request: UUHttpRequest, payload: Data) -> UUHttpResponse
{
    let urlResponse = HTTPURLResponse(
        url: URL(string: request.url)!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: [UUHttpHeader.contentType: "application/octet-stream"])!
    return UUHttpResponse(
        request: request,
        response: urlResponse,
        rawResponse: payload,
        parsedResponse: payload)
}

private enum CancelDownloadTestError: LocalizedError
{
    case conditionNotMetInTime
    case handlerCalledWhenUnexpected

    var errorDescription: String?
    {
        switch self
        {
            case .conditionNotMetInTime:
                "Expected condition was not met before timeout"
            case .handlerCalledWhenUnexpected:
                "Completion handler was invoked after cancel"
        }
    }
}

private final class ExecuteCounter: @unchecked Sendable
{
    private let lock = NSLock()
    private var count = 0
    private(set) var urls: [String] = []

    @discardableResult
    func record(url: String) -> Int
    {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        urls.append(url)
        return count
    }

    var value: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func reset()
    {
        lock.lock()
        count = 0
        urls.removeAll()
        lock.unlock()
    }
}

private actor DownloadGate
{
    private var isBlocking = false

    func block()
    {
        isBlocking = true
    }

    func waitIfBlocking() async
    {
        while true
        {
            if Task.isCancelled
            {
                return
            }

            guard isBlocking else { return }

            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func release()
    {
        isBlocking = false
    }
}

private final class HandlerCalledFlag: @unchecked Sendable
{
    private let lock = NSLock()
    private var _called = false
    private var receivedData: Data?
    private var receivedError: Error?

    var called: Bool
    {
        lock.lock()
        defer { lock.unlock() }
        return _called
    }

    func markCalled(data: Data?, error: Error?)
    {
        lock.lock()
        _called = true
        receivedData = data
        receivedError = error
        lock.unlock()
    }

    func snapshot() -> (called: Bool, data: Data?, error: Error?)
    {
        lock.lock()
        defer { lock.unlock() }
        return (_called, receivedData, receivedError)
    }
}

private final class ControllableRemoteApi: UURemoteApi, @unchecked Sendable
{
    let testSession = TestHttpSession()

    override init()
    {
        super.init()
        session = testSession
    }
}

private final class TestHttpSession: UUHttpSession, @unchecked Sendable
{
    var executeRequestHandler: (UUHttpRequest) async -> UUHttpResponse = { request in
        UUHttpResponse(request: request, parsedResponse: "ok")
    }

    override func executeRequest(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        await executeRequestHandler(request)
    }
}

// MARK: -

final class UURemoteDataCancelDownloadTests: XCTestCase
{
    private var cache: UUDataCache!
    private var remoteApi: ControllableRemoteApi!
    private var remoteData: UURemoteData!
    private let gate = DownloadGate()
    private let executeCounter = ExecuteCounter()

    override func setUp() async throws
    {
        try await super.setUp()

        let cacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UURemoteDataCancelTests-\(UUID().uuidString)", isDirectory: true)
        cache = UUDataCache(cacheLocation: cacheDir.path)
        remoteApi = ControllableRemoteApi()
        remoteData = UURemoteData(dataCache: cache, remoteApi: remoteApi)
        remoteData.maxActiveRequests = 0
        remoteData.notificationQueue = DispatchQueue(label: "com.silverpine.uu.test.cancel.notification", qos: .utility)

        await gate.release()
        executeCounter.reset()

        remoteApi.testSession.executeRequestHandler =
        { [gate, executeCounter] request in
            executeCounter.record(url: request.url)
            await gate.waitIfBlocking()
            return cancelTestHttpResponse(request: request, payload: cancelTestPayload())
        }
    }

    override func tearDown() async throws
    {
        await gate.release()
        await cache.clearCache()
        remoteData.clearMemoryCache()
        try await super.tearDown()
    }

    private func waitUntil(
        timeoutSeconds: TimeInterval = 5,
        _ condition: @escaping () async -> Bool) async throws
    {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !(await condition())
        {
            if Date() > deadline
            {
                throw CancelDownloadTestError.conditionNotMetInTime
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func waitUntilInactive(for key: String, timeoutSeconds: TimeInterval = 5) async throws
    {
        try await waitUntil(timeoutSeconds: timeoutSeconds)
        {
            !(await self.remoteData.isDownloadActive(for: key))
        }
    }

    private func waitUntilActive(for key: String, timeoutSeconds: TimeInterval = 5) async throws
    {
        try await waitUntil(timeoutSeconds: timeoutSeconds)
        {
            await self.remoteData.isDownloadActive(for: key)
        }
    }

    private func assertHandlerNeverCalled(_ flag: HandlerCalledFlag, within seconds: TimeInterval = 1) async throws
    {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() <= deadline
        {
            if flag.called
            {
                throw CancelDownloadTestError.handlerCalledWhenUnexpected
            }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
    }

    // MARK: - In-flight cancellation

    func test_cancelDownload_inFlightStopsActiveDownload() async throws
    {
        let key = cancelTestKey("in-flight-active")
        await gate.block()

        _ = await remoteData.data(for: key)
        try await waitUntilActive(for: key)

        remoteData.cancelDownload(for: key)
        try await waitUntilInactive(for: key)

        let stillActive = await remoteData.isDownloadActive(for: key)
        XCTAssertFalse(stillActive)
    }

    func test_cancelDownload_inFlightDoesNotCacheData() async throws
    {
        let key = cancelTestKey("in-flight-no-cache")
        await gate.block()

        _ = await remoteData.data(for: key)
        try await waitUntilActive(for: key)

        remoteData.cancelDownload(for: key)
        await gate.release()
        try await waitUntilInactive(for: key)

        let cachedExists = await remoteData.cachedDataExists(for: key)
        XCTAssertFalse(cachedExists)
        let diskData = await cache.data(for: key)
        XCTAssertNil(diskData)
    }

    func test_cancelDownload_inFlightDoesNotInvokeCompletionHandler() async throws
    {
        let key = cancelTestKey("in-flight-no-handler")
        let handlerFlag = HandlerCalledFlag()
        await gate.block()

        _ = await remoteData.data(for: key, remoteLoadCompletion:
        { data, error in
            handlerFlag.markCalled(data: data, error: error)
        })

        try await waitUntilActive(for: key)
        remoteData.cancelDownload(for: key)
        await gate.release()
        try await waitUntilInactive(for: key)

        try await assertHandlerNeverCalled(handlerFlag)
    }

    func test_cancelDownload_inFlightDoesNotPostDownloadNotifications() async throws
    {
        let key = cancelTestKey("in-flight-no-notify")
        await gate.block()

        let successExp = expectation(description: "success notification")
        successExp.isInverted = true
        let failureExp = expectation(description: "failure notification")
        failureExp.isInverted = true

        let successObserver = NotificationCenter.default.addObserver(
            forName: UURemoteData.Notifications.DataDownloaded,
            object: nil,
            queue: nil)
        { notification in
            if notification.uuRemoteDataPath == key
            {
                successExp.fulfill()
            }
        }

        let failureObserver = NotificationCenter.default.addObserver(
            forName: UURemoteData.Notifications.DataDownloadFailed,
            object: nil,
            queue: nil)
        { notification in
            if notification.uuRemoteDataPath == key
            {
                failureExp.fulfill()
            }
        }

        defer
        {
            NotificationCenter.default.removeObserver(successObserver)
            NotificationCenter.default.removeObserver(failureObserver)
        }

        _ = await remoteData.data(for: key)
        try await waitUntilActive(for: key)

        remoteData.cancelDownload(for: key)
        await gate.release()
        try await waitUntilInactive(for: key)

        await fulfillment(of: [successExp, failureExp], timeout: 0.5)
    }

    func test_cancelDownload_inFlightCoalescedWaitersDoNotReceiveHandlers() async throws
    {
        let key = cancelTestKey("in-flight-coalesced")
        await gate.block()

        let handlerOne = HandlerCalledFlag()
        let handlerTwo = HandlerCalledFlag()

        async let firstRequest: Data? = remoteData.data(for: key, remoteLoadCompletion:
        { data, error in
            handlerOne.markCalled(data: data, error: error)
        })

        try await waitUntilActive(for: key)

        _ = await remoteData.data(for: key, remoteLoadCompletion:
        { data, error in
            handlerTwo.markCalled(data: data, error: error)
        })

        remoteData.cancelDownload(for: key)
        await gate.release()
        try await waitUntilInactive(for: key)

        _ = await firstRequest

        try await assertHandlerNeverCalled(handlerOne)
        try await assertHandlerNeverCalled(handlerTwo)
        XCTAssertEqual(executeCounter.value, 1)
    }

    // MARK: - Pending queue cancellation

    func test_cancelDownload_pendingRequestIsRemovedAndNeverExecutes() async throws
    {
        let activeKey = cancelTestKey("pending-active")
        let pendingKey = cancelTestKey("pending-queued")
        await gate.block()

        _ = await remoteData.data(for: activeKey)
        try await waitUntilActive(for: activeKey)

        _ = await remoteData.data(for: pendingKey)
        try await Task.sleep(nanoseconds: 100_000_000)
        let pendingActive = await remoteData.isDownloadActive(for: pendingKey)
        XCTAssertFalse(pendingActive)

        remoteData.cancelDownload(for: pendingKey)

        await gate.release()
        try await waitUntilInactive(for: activeKey)

        XCTAssertFalse(executeCounter.urls.contains(pendingKey))
        let pendingCached = await remoteData.cachedDataExists(for: pendingKey)
        XCTAssertFalse(pendingCached)
    }

    func test_cancelDownload_pendingCancellationAllowsNextQueuedDownloadToRun() async throws
    {
        let activeKey = cancelTestKey("queue-active")
        let cancelledPendingKey = cancelTestKey("queue-cancelled")
        let nextPendingKey = cancelTestKey("queue-next")
        await gate.block()

        _ = await remoteData.data(for: activeKey)
        try await waitUntilActive(for: activeKey)

        _ = await remoteData.data(for: cancelledPendingKey)
        _ = await remoteData.data(for: nextPendingKey)
        try await Task.sleep(nanoseconds: 100_000_000)

        remoteData.cancelDownload(for: cancelledPendingKey)

        await gate.release()
        try await waitUntilInactive(for: activeKey)
        try await waitUntil(timeoutSeconds: 5)
        {
            self.executeCounter.urls.contains(nextPendingKey)
        }

        XCTAssertFalse(executeCounter.urls.contains(cancelledPendingKey))
        XCTAssertTrue(executeCounter.urls.contains(nextPendingKey))
    }

    // MARK: - Generation invalidation

    func test_cancelDownload_invalidatesInFlightRequestGeneration() async throws
    {
        let key = cancelTestKey("generation")

        remoteData.cancelDownload(for: key)
        _ = await remoteData.data(for: key)
        remoteData.cancelDownload(for: key)

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(executeCounter.value, 0)
        let cachedExists = await remoteData.cachedDataExists(for: key)
        XCTAssertFalse(cachedExists)
    }

    // MARK: - Pending queue cancellation

    func test_cancelDownload_allowsSubsequentDownloadToSucceed() async throws
    {
        let key = cancelTestKey("restart")
        let payload = cancelTestPayload()
        await gate.block()

        _ = await remoteData.data(for: key)
        try await waitUntilActive(for: key)
        remoteData.cancelDownload(for: key)
        await gate.release()
        try await waitUntilInactive(for: key)

        await gate.block()
        let handlerFlag = HandlerCalledFlag()
        let completionExp = expectation(description: "restart handler")

        _ = await remoteData.data(for: key, remoteLoadCompletion:
        { data, error in
            handlerFlag.markCalled(data: data, error: error)
            completionExp.fulfill()
        })

        try await waitUntilActive(for: key)
        await gate.release()
        await fulfillment(of: [completionExp], timeout: 5)

        let cached = await remoteData.data(for: key)
        XCTAssertEqual(cached, payload)

        let snapshot = handlerFlag.snapshot()
        XCTAssertEqual(snapshot.data, payload)
        XCTAssertNil(snapshot.error)
        XCTAssertEqual(executeCounter.value, 2)
    }

    func test_cancelDownload_doesNotAffectOtherKeys() async throws
    {
        let cancelledKey = cancelTestKey("other-cancelled")
        let activeKey = cancelTestKey("other-active")
        await gate.block()

        _ = await remoteData.data(for: cancelledKey)
        _ = await remoteData.data(for: activeKey)
        try await waitUntilActive(for: cancelledKey)

        remoteData.cancelDownload(for: cancelledKey)
        try await waitUntilInactive(for: cancelledKey)

        try await waitUntil(timeoutSeconds: 5)
        {
            self.executeCounter.urls.contains(activeKey)
        }

        await gate.release()
        try await waitUntilInactive(for: activeKey)

        let activeCached = await remoteData.cachedDataExists(for: activeKey)
        let cancelledCached = await remoteData.cachedDataExists(for: cancelledKey)
        XCTAssertTrue(activeCached)
        XCTAssertFalse(cancelledCached)
    }

    func test_cancelDownload_onCachedKeyIsHarmless() async throws
    {
        let key = cancelTestKey("cached-noop")
        let payload = cancelTestPayload(0x22)

        await remoteData.save(data: payload, key: key)
        remoteData.cancelDownload(for: key)

        let cached = await remoteData.data(for: key)
        XCTAssertEqual(cached, payload)
        XCTAssertEqual(executeCounter.value, 0)
    }

    func test_cancelDownload_doesNotRemoveExistingCachedData() async throws
    {
        let key = cancelTestKey("keep-cache")
        let payload = cancelTestPayload(0x33)

        await remoteData.save(data: payload, key: key)
        await gate.block()

        _ = await remoteData.data(for: key)
        try await Task.sleep(nanoseconds: 50_000_000)

        remoteData.cancelDownload(for: key)
        await gate.release()

        let cached = await remoteData.data(for: key)
        XCTAssertEqual(cached, payload)
    }

    // MARK: - Race with completion

    func test_cancelDownload_raceWithCompletion_doesNotCacheWhenCancelledFirst() async throws
    {
        let key = cancelTestKey("race")
        await gate.block()

        _ = await remoteData.data(for: key)
        try await waitUntilActive(for: key)

        remoteData.cancelDownload(for: key)
        await gate.release()
        try await waitUntilInactive(for: key)
        try await Task.sleep(nanoseconds: 200_000_000)

        let cachedExists = await remoteData.cachedDataExists(for: key)
        XCTAssertFalse(cachedExists)
    }

    // MARK: - Invalid keys

    func test_cancelDownload_invalidUrlKeyIsHarmless() async throws
    {
        let invalidKey = "ht tp://x"
        remoteData.cancelDownload(for: invalidKey)
        _ = await remoteData.data(for: invalidKey)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(executeCounter.value, 0)
    }

    func test_cancelDownload_multipleCallsForSameKeyAreHarmless() async throws
    {
        let key = cancelTestKey("idempotent")
        await gate.block()

        _ = await remoteData.data(for: key)
        try await waitUntilActive(for: key)

        remoteData.cancelDownload(for: key)
        remoteData.cancelDownload(for: key)
        remoteData.cancelDownload(for: key)

        try await waitUntilInactive(for: key)
        await gate.release()
        try await Task.sleep(nanoseconds: 100_000_000)

        let cachedExists = await remoteData.cachedDataExists(for: key)
        XCTAssertFalse(cachedExists)
    }

    func test_cancelDownload_doesNotRemoveHandlersForOtherKeys() async throws
    {
        let cancelledKey = cancelTestKey("handler-cancelled")
        let otherKey = cancelTestKey("handler-other")
        await gate.block()

        let otherHandler = HandlerCalledFlag()

        _ = await remoteData.data(for: cancelledKey)
        _ = await remoteData.data(for: otherKey, remoteLoadCompletion:
        { data, error in
            otherHandler.markCalled(data: data, error: error)
        })

        try await waitUntilActive(for: cancelledKey)
        remoteData.cancelDownload(for: cancelledKey)
        try await waitUntilInactive(for: cancelledKey)

        await gate.release()
        try await waitUntilInactive(for: otherKey)

        let snapshot = otherHandler.snapshot()
        XCTAssertTrue(snapshot.called)
        XCTAssertEqual(snapshot.data, cancelTestPayload())
        XCTAssertNil(snapshot.error)
    }
}
