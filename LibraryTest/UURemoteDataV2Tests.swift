//
//  UURemoteDataV2Tests.swift
//  UUSwiftNetworking
//
//  Unit tests for UURemoteDataV2, UURemoteDataV2Api, and UURemoteDataV2ResponseHandler.
//  All behavior is verified with mocks; no live network or shared singletons are used.
//

import XCTest
import UUSwiftCore
@testable import UUSwiftNetworking

// MARK: - Test Support

private enum V2TestError: Error
{
    case timeout
}

private func v2Key(_ name: String) -> String
{
    "https://remote-data-v2-test.example.com/\(name)-\(UUID().uuidString).bin"
}

private func v2Payload(_ seed: UInt8 = 0x10) -> Data
{
    Data([seed, seed &+ 1, seed &+ 2, seed &+ 3])
}

private func v2HttpResponse(url: String, statusCode: Int) -> HTTPURLResponse
{
    HTTPURLResponse(
        url: URL(string: url)!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: [UUHttpHeader.contentType: "application/octet-stream"])!
}

/// A blocking gate used to hold a mock download in flight for deterministic concurrency tests.
private actor V2Gate
{
    private var isBlocking = false

    func block()
    {
        isBlocking = true
    }

    func release()
    {
        isBlocking = false
    }

    func waitIfBlocking() async
    {
        while isBlocking
        {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
    }
}

/// Transport tuple returned by the mock session before the response handler runs.
private struct V2Transport: @unchecked Sendable
{
    let data: Data?
    let response: HTTPURLResponse?
    let error: Error?
}

/// A mock `UUHttpSession` that records calls and runs the request's installed response handler,
/// exercising the real parse pipeline end-to-end.
private final class V2MockSession: UUHttpSession, @unchecked Sendable
{
    private let lock = NSLock()
    private var _requestCount = 0
    private var _requestedUrls: [String] = []

    var transportProvider: @Sendable (UUHttpRequest) async -> V2Transport =
    { request in
        V2Transport(data: v2Payload(), response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
    }

    var requestCount: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return _requestCount
    }

    var requestedUrls: [String]
    {
        lock.lock()
        defer { lock.unlock() }
        return _requestedUrls
    }

    private func record(_ url: String)
    {
        lock.lock()
        defer { lock.unlock() }
        _requestCount += 1
        _requestedUrls.append(url)
    }

    override func executeRequest(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        record(request.url)

        guard let httpRequest = await request.buildURLRequest() else
        {
            return UUHttpResponse(request: request, response: nil, error: UUErrorFactory.createInvalidRequestError(request))
        }

        request.httpRequest = httpRequest

        let transport = await transportProvider(request)
        return await request.handleResponse(data: transport.data, response: transport.response, error: transport.error)
    }
}

/// A `UURemoteDataV2Api` wired to a mock session.
private final class V2MockApi: UURemoteDataV2Api, @unchecked Sendable
{
    let mockSession: V2MockSession

    init(mockSession: V2MockSession)
    {
        self.mockSession = mockSession
        super.init()
        session = mockSession
    }
}

/// A mock disk cache with read / write counters for verifying cache tier ordering.
private final class V2MockDataCache: UUDataCacheProtocol, @unchecked Sendable
{
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private var metadata: [String: [String: Any]] = [:]
    private var _dataReadCount = 0
    private var _dataWriteCount = 0

    var dataReadCount: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return _dataReadCount
    }

    var dataWriteCount: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return _dataWriteCount
    }

    func storedData(for key: String) -> Data?
    {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func seed(_ data: Data, for key: String)
    {
        lock.lock()
        storage[key] = data
        lock.unlock()
    }

    // MARK: UUDataCacheProtocol
    //
    // NSLock.unlock() is unavailable from async contexts under Swift 6, so all locked work is
    // delegated to synchronous helpers below.

    func data(for key: String) async -> Data?
    {
        readData(key)
    }

    func set(data: Data, for key: String) async
    {
        writeData(data, key)
    }

    func metaData(for key: String) async -> [String:Any]
    {
        readMetaData(key)
    }

    func set(metaData: [String:Any], for key: String) async
    {
        writeMetaData(metaData, key)
    }

    func dataExists(for key: String) async -> Bool
    {
        storedData(for: key) != nil
    }

    func isDataExpired(for key: String) async -> Bool
    {
        false
    }

    func removeData(for key: String) async
    {
        remove(key)
    }

    func clearCache() async
    {
        clear()
    }

    func purgeExpiredData() async
    {
    }

    func listKeys() async -> [String]
    {
        keys()
    }

    // MARK: Synchronous locked helpers

    private func readData(_ key: String) -> Data?
    {
        lock.lock()
        defer { lock.unlock() }
        _dataReadCount += 1
        return storage[key]
    }

    private func writeData(_ data: Data, _ key: String)
    {
        lock.lock()
        defer { lock.unlock() }
        _dataWriteCount += 1
        storage[key] = data
    }

    private func readMetaData(_ key: String) -> [String:Any]
    {
        lock.lock()
        defer { lock.unlock() }
        return metadata[key] ?? [:]
    }

    private func writeMetaData(_ value: [String:Any], _ key: String)
    {
        lock.lock()
        defer { lock.unlock() }
        metadata[key] = value
    }

    private func remove(_ key: String)
    {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
        metadata.removeValue(forKey: key)
    }

    private func clear()
    {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
        metadata.removeAll()
    }

    private func keys() -> [String]
    {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.keys)
    }
}

// MARK: - Tests

final class UURemoteDataV2Tests: XCTestCase
{
    private var cache: V2MockDataCache!
    private var session: V2MockSession!
    private var api: V2MockApi!
    private var sut: UURemoteDataV2!

    override func setUp() async throws
    {
        try await super.setUp()
        cache = V2MockDataCache()
        session = V2MockSession()
        api = V2MockApi(mockSession: session)
        sut = UURemoteDataV2(dataCache: cache, remoteApi: api)
    }

    override func tearDown() async throws
    {
        sut = nil
        api = nil
        session = nil
        cache = nil
        try await super.tearDown()
    }

    private func waitUntil(
        timeout: TimeInterval = 3.0,
        _ condition: () -> Bool) async throws
    {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition()
        {
            if Date() > deadline
            {
                throw V2TestError.timeout
            }
            try await Task.sleep(nanoseconds: 3_000_000)
        }
    }

    // MARK: Network tier

    func test_data_fetchesFromNetwork_whenNotCached() async throws
    {
        let key = v2Key("network")
        let payload = v2Payload(0x21)
        session.transportProvider = { request in
            V2Transport(data: payload, response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let result = try await sut.data(for: key)

        XCTAssertEqual(result, payload)
        XCTAssertEqual(session.requestCount, 1)
    }

    func test_data_storesToDiskAndMemory_afterDownload() async throws
    {
        let key = v2Key("store")
        let payload = v2Payload(0x31)
        session.transportProvider = { request in
            V2Transport(data: payload, response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        _ = try await sut.data(for: key)

        XCTAssertEqual(cache.storedData(for: key), payload, "Download should be written to disk cache")
        XCTAssertEqual(cache.dataWriteCount, 1, "Download should write to disk exactly once")
        XCTAssertEqual(sut.memoryCachedData(for: key), payload, "Download should be written to memory cache")
    }

    // MARK: Memory tier

    func test_data_returnsFromMemory_withoutDiskOrNetwork() async throws
    {
        let key = v2Key("memory")
        let payload = v2Payload(0x41)
        session.transportProvider = { request in
            V2Transport(data: payload, response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        // Prime memory + disk via first download.
        _ = try await sut.data(for: key)
        let diskReadsAfterPrime = cache.dataReadCount

        // Second call should be served entirely from memory.
        let result = try await sut.data(for: key)

        XCTAssertEqual(result, payload)
        XCTAssertEqual(session.requestCount, 1, "Memory hit must not trigger a network fetch")
        XCTAssertEqual(cache.dataReadCount, diskReadsAfterPrime, "Memory hit must not read the disk cache")
    }

    // MARK: Disk tier

    func test_data_returnsFromDisk_whenMemoryEmpty() async throws
    {
        let key = v2Key("disk")
        let payload = v2Payload(0x51)
        cache.seed(payload, for: key)

        let result = try await sut.data(for: key)

        XCTAssertEqual(result, payload)
        XCTAssertEqual(session.requestCount, 0, "Disk hit must not trigger a network fetch")
        XCTAssertEqual(cache.dataReadCount, 1, "Disk hit should read the disk cache once")
        XCTAssertEqual(sut.memoryCachedData(for: key), payload, "Disk hit should warm the memory cache")
    }

    func test_clearMemoryCache_forcesDiskLookup() async throws
    {
        let key = v2Key("clear-memory")
        let payload = v2Payload(0x61)
        session.transportProvider = { request in
            V2Transport(data: payload, response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        _ = try await sut.data(for: key)
        XCTAssertNotNil(sut.memoryCachedData(for: key))

        sut.clearMemoryCache()
        XCTAssertNil(sut.memoryCachedData(for: key))

        let result = try await sut.data(for: key)
        XCTAssertEqual(result, payload)
        XCTAssertEqual(session.requestCount, 1, "Second fetch should be served by disk, not network")
    }

    // MARK: Coalescing

    func test_concurrentRequests_sameUrl_coalesceToSingleFetch() async throws
    {
        let key = v2Key("coalesce")
        let payload = v2Payload(0x71)
        let gate = V2Gate()
        await gate.block()

        session.transportProvider = { request in
            await gate.waitIfBlocking()
            return V2Transport(data: payload, response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let sut = self.sut!
        let waiterCount = 25
        let tasks = (0..<waiterCount).map
        { _ in
            Task { try await sut.data(for: key) }
        }

        try await waitUntil { self.session.requestCount == 1 }
        await gate.release()

        for task in tasks
        {
            let result = try await task.value
            XCTAssertEqual(result, payload)
        }

        XCTAssertEqual(session.requestCount, 1, "Concurrent requests for the same URL must share one network fetch")
        XCTAssertEqual(cache.dataWriteCount, 1, "Coalesced download must persist exactly once")
    }

    func test_concurrentRequests_differentUrls_doNotCoalesce() async throws
    {
        let keyA = v2Key("coalesce-a")
        let keyB = v2Key("coalesce-b")
        session.transportProvider = { request in
            V2Transport(data: v2Payload(), response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let sut = self.sut!
        async let a = sut.data(for: keyA)
        async let b = sut.data(for: keyB)
        _ = try await (a, b)

        XCTAssertEqual(session.requestCount, 2, "Different URLs must not coalesce")
    }

    func test_sequentialRequests_afterCompletion_useCacheNotNetwork() async throws
    {
        let key = v2Key("sequential")
        session.transportProvider = { request in
            V2Transport(data: v2Payload(), response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        _ = try await sut.data(for: key)
        _ = try await sut.data(for: key)
        _ = try await sut.data(for: key)

        XCTAssertEqual(session.requestCount, 1)
    }

    // MARK: Cancellation

    func test_cancellation_inFlight_throwsCancellationError() async throws
    {
        let key = v2Key("cancel")
        let gate = V2Gate()
        await gate.block()

        session.transportProvider = { request in
            await gate.waitIfBlocking()
            return V2Transport(data: v2Payload(), response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let sut = self.sut!
        let task = Task { () -> Result<Data, Error> in
            do
            {
                return .success(try await sut.data(for: key))
            }
            catch
            {
                return .failure(error)
            }
        }

        try await waitUntil { self.session.requestCount == 1 }
        task.cancel()
        await gate.release()

        let result = await task.value
        switch result
        {
            case .success:
                XCTFail("Expected cancellation to throw")

            case .failure(let error):
                XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(error)")
        }
    }

    func test_cancellingOneWaiter_otherWaiterStillReceivesData() async throws
    {
        let key = v2Key("cancel-coalesced")
        let payload = v2Payload(0x81)
        let gate = V2Gate()
        await gate.block()

        session.transportProvider = { request in
            await gate.waitIfBlocking()
            return V2Transport(data: payload, response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let sut = self.sut!
        let cancelledTask = Task { () -> Result<Data, Error> in
            do { return .success(try await sut.data(for: key)) }
            catch { return .failure(error) }
        }
        let survivingTask = Task { () -> Result<Data, Error> in
            do { return .success(try await sut.data(for: key)) }
            catch { return .failure(error) }
        }

        try await waitUntil { self.session.requestCount == 1 }
        cancelledTask.cancel()
        await gate.release()

        let cancelledResult = await cancelledTask.value
        let survivingResult = await survivingTask.value

        if case .success = cancelledResult
        {
            XCTFail("Cancelled waiter should not succeed")
        }

        switch survivingResult
        {
            case .success(let data):
                XCTAssertEqual(data, payload, "Surviving waiter should receive the shared download")

            case .failure(let error):
                XCTFail("Surviving waiter should not fail: \(error)")
        }

        XCTAssertEqual(session.requestCount, 1, "Cancelling one waiter must not start a second fetch")
    }

    // MARK: Error handling

    func test_data_throwsInvalidUrl_forUnparseableKey() async throws
    {
        do
        {
            _ = try await sut.data(for: "")
            XCTFail("Expected invalidUrl error")
        }
        catch let error as UURemoteDataV2Error
        {
            guard case .invalidUrl = error else
            {
                return XCTFail("Expected invalidUrl, got \(error)")
            }
        }

        XCTAssertEqual(session.requestCount, 0)
    }

    func test_data_throwsHttpError_onNonSuccessStatus() async throws
    {
        let key = v2Key("http-error")
        session.transportProvider = { request in
            V2Transport(data: Data("not found".utf8), response: v2HttpResponse(url: request.url, statusCode: 404), error: nil)
        }

        do
        {
            _ = try await sut.data(for: key)
            XCTFail("Expected HTTP error to be thrown")
        }
        catch
        {
            XCTAssertEqual(error.uuHttpStatusCode, 404)
        }

        XCTAssertNil(cache.storedData(for: key), "Failed download must not be cached")
    }

    func test_failedDownload_isNotCached_andRetriesOnNextRequest() async throws
    {
        let key = v2Key("retry")
        session.transportProvider = { request in
            V2Transport(data: Data("err".utf8), response: v2HttpResponse(url: request.url, statusCode: 500), error: nil)
        }

        _ = try? await sut.data(for: key)
        XCTAssertEqual(session.requestCount, 1)

        _ = try? await sut.data(for: key)
        XCTAssertEqual(session.requestCount, 2, "A failed download must not be cached and should retry")
    }

    func test_data_throwsEmptyResponse_onEmptyBody() async throws
    {
        let key = v2Key("empty")
        session.transportProvider = { request in
            V2Transport(data: Data(), response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        do
        {
            _ = try await sut.data(for: key)
            XCTFail("Expected emptyResponse error")
        }
        catch let error as UURemoteDataV2Error
        {
            guard case .emptyResponse = error else
            {
                return XCTFail("Expected emptyResponse, got \(error)")
            }
        }
    }

    // MARK: Extensibility (transform hook)

    func test_transformHook_isAppliedAndCached() async throws
    {
        let key = v2Key("transform")
        let payload = v2Payload(0x91)
        let suffix = Data([0xFF])

        let session = V2MockSession()
        session.transportProvider = { request in
            V2Transport(data: payload, response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let cache = V2MockDataCache()
        let api = V2MockApi(mockSession: session)
        let transforming = TransformingRemoteData(suffix: suffix, dataCache: cache, remoteApi: api)

        let result = try await transforming.data(for: key)

        XCTAssertEqual(result, payload + suffix, "transform output should be returned")
        XCTAssertEqual(cache.storedData(for: key), payload + suffix, "transform output should be cached")
    }

    // MARK: Response handler

    func test_responseHandler_parsesBinaryData_onSuccess() async throws
    {
        let key = v2Key("handler-success")
        let payload = v2Payload(0xA1)

        let request = UUHttpRequest(url: key)
        request.httpRequest = await request.buildURLRequest()

        let handler = UURemoteDataV2ResponseHandler()
        let response = await handler.handleResponse(
            request: request,
            data: payload,
            response: v2HttpResponse(url: key, statusCode: 200),
            error: nil)

        XCTAssertNil(response.httpError)
        XCTAssertEqual(response.parsedResponse as? Data, payload)
    }

    func test_responseHandler_setsHttpError_onNonSuccess() async throws
    {
        let key = v2Key("handler-error")

        let request = UUHttpRequest(url: key)
        request.httpRequest = await request.buildURLRequest()

        let handler = UURemoteDataV2ResponseHandler()
        let response = await handler.handleResponse(
            request: request,
            data: Data("nope".utf8),
            response: v2HttpResponse(url: key, statusCode: 404),
            error: nil)

        XCTAssertNotNil(response.httpError)
        XCTAssertEqual(response.httpStatusCode, 404)
    }

    // MARK: Remote API

    func test_api_prepareRequest_installsResponseHandler() async throws
    {
        let api = UURemoteDataV2Api()
        let request = UUHttpRequest(url: v2Key("api-prepare"))

        await api.prepareRequest(request)

        XCTAssertTrue(request.responseHandler is UURemoteDataV2ResponseHandler)
    }

    func test_api_makeResponseHandler_isOverridable() async throws
    {
        let api = CustomHandlerApi()
        let request = UUHttpRequest(url: v2Key("api-custom"))

        await api.prepareRequest(request)

        XCTAssertTrue(request.responseHandler is CustomResponseHandler)
    }

    func test_api_executeRequest_parsesThroughInstalledHandler() async throws
    {
        let key = v2Key("api-execute")
        let payload = v2Payload(0xB1)
        let session = V2MockSession()
        session.transportProvider = { request in
            V2Transport(data: payload, response: v2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }
        let api = V2MockApi(mockSession: session)

        let response = await api.executeRequest(UUHttpRequest(url: key))

        XCTAssertNil(response.httpError)
        XCTAssertEqual(response.parsedResponse as? Data, payload)
        XCTAssertEqual(session.requestCount, 1)
    }
}

// MARK: - Subclasses under test

private final class TransformingRemoteData: UURemoteDataV2, @unchecked Sendable
{
    private let suffix: Data

    init(suffix: Data, dataCache: UUDataCacheProtocol, remoteApi: UURemoteDataV2Api)
    {
        self.suffix = suffix
        super.init(dataCache: dataCache, remoteApi: remoteApi)
    }

    override func transform(downloadedData data: Data, for url: String) async throws -> Data
    {
        data + suffix
    }
}

private final class CustomResponseHandler: UURemoteDataV2ResponseHandler
{
}

private final class CustomHandlerApi: UURemoteDataV2Api, @unchecked Sendable
{
    override func makeResponseHandler() -> UUHttpResponseHandler
    {
        CustomResponseHandler()
    }
}
