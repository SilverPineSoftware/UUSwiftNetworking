//
//  UURemoteObjectTests.swift
//  UUSwiftNetworking
//
//  Unit tests for UURemoteObject, UUObjectBox, UURemoteObjectApi, and
//  UURemoteObjectResponseHandler. All behavior is verified with mocks; no live network or shared
//  singletons are used.
//

import XCTest
import UUSwiftCore
@testable import UUSwiftNetworking

// MARK: - Test Support

private enum ObjectTestError: Error
{
    case timeout
}

private func objectKey(_ name: String) -> String
{
    "https://remote-object-test.example.com/\(name)-\(UUID().uuidString).bin"
}

private func objectPayload(_ seed: UInt8 = 0x10) -> Data
{
    Data([seed, seed &+ 1, seed &+ 2, seed &+ 3])
}

private func objectHttpResponse(url: String, statusCode: Int) -> HTTPURLResponse
{
    HTTPURLResponse(
        url: URL(string: url)!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: [UUHttpHeader.contentType: "application/octet-stream"])!
}

private actor ObjectGate
{
    private var isBlocking = false

    func block() { isBlocking = true }
    func release() { isBlocking = false }

    func waitIfBlocking() async
    {
        while isBlocking
        {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
    }
}

private struct ObjectTransport: @unchecked Sendable
{
    let data: Data?
    let response: HTTPURLResponse?
    let error: Error?
}

private final class ObjectMockSession: UUHttpSession, @unchecked Sendable
{
    private let lock = NSLock()
    private var _requestCount = 0

    var transportProvider: @Sendable (UUHttpRequest) async -> ObjectTransport =
    { request in
        ObjectTransport(data: objectPayload(), response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
    }

    var requestCount: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return _requestCount
    }

    private func recordCall()
    {
        lock.lock()
        defer { lock.unlock() }
        _requestCount += 1
    }

    override func executeRequest(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        recordCall()

        guard let httpRequest = await request.buildURLRequest() else
        {
            return UUHttpResponse(request: request, response: nil, error: UUErrorFactory.createInvalidRequestError(request))
        }

        request.httpRequest = httpRequest

        let transport = await transportProvider(request)
        return await request.handleResponse(data: transport.data, response: transport.response, error: transport.error)
    }
}

private final class ObjectMockApi: UURemoteObjectApi, @unchecked Sendable
{
    let mockSession: ObjectMockSession

    init(mockSession: ObjectMockSession)
    {
        self.mockSession = mockSession
        super.init()
        session = mockSession
    }
}

private final class ObjectMockDataCache: UUDataCacheProtocol, @unchecked Sendable
{
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private var metadata: [String: [String: Any]] = [:]
    private var _dataReadCount = 0
    private var _dataWriteCount = 0
    private var _metaWriteCount = 0

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

    var metaWriteCount: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return _metaWriteCount
    }

    func storedData(for key: String) -> Data?
    {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func storedMetaData(for key: String) -> [String: Any]
    {
        lock.lock()
        defer { lock.unlock() }
        return metadata[key] ?? [:]
    }

    func seed(_ data: Data, for key: String)
    {
        lock.lock()
        storage[key] = data
        lock.unlock()
    }

    func data(for key: String) async -> Data? { readData(key) }
    func set(data: Data, for key: String) async { writeData(data, key) }
    func metaData(for key: String) async -> [String: Any] { readMeta(key) }
    func set(metaData: [String: Any], for key: String) async { writeMeta(metaData, key) }
    func dataExists(for key: String) async -> Bool { storedData(for: key) != nil }
    func isDataExpired(for key: String) async -> Bool { false }
    func removeData(for key: String) async { remove(key) }
    func clearCache() async { clear() }
    func purgeExpiredData() async { }
    func listKeys() async -> [String] { keys() }

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

    private func readMeta(_ key: String) -> [String: Any]
    {
        lock.lock()
        defer { lock.unlock() }
        return metadata[key] ?? [:]
    }

    private func writeMeta(_ value: [String: Any], _ key: String)
    {
        lock.lock()
        defer { lock.unlock() }
        _metaWriteCount += 1
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

final class UURemoteObjectTests: XCTestCase
{
    private var cache: ObjectMockDataCache!
    private var session: ObjectMockSession!
    private var api: ObjectMockApi!
    private var sut: UURemoteObject<Data>!

    override func setUp() async throws
    {
        try await super.setUp()
        cache = ObjectMockDataCache()
        session = ObjectMockSession()
        api = ObjectMockApi(mockSession: session)
        sut = UURemoteObject<Data>(dataCache: cache, remoteApi: api)
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
            if Date() > deadline { throw ObjectTestError.timeout }
            try await Task.sleep(nanoseconds: 3_000_000)
        }
    }

    // MARK: UUObjectBox

    func test_objectBox_wrapsAndUnwrapsValue() async throws
    {
        let payload = objectPayload(0xAA)
        let box = UUObjectBox(payload)

        XCTAssertEqual(box.value, payload)
    }

    // MARK: UURemoteObjectError

    func test_error_invalidUrl_hasLocalizedDescription() async throws
    {
        let error = UURemoteObjectError.invalidUrl("not-a-url")
        XCTAssertTrue(error.localizedDescription.contains("not-a-url"))
    }

    func test_error_decodeFailed_hasLocalizedDescription() async throws
    {
        let error = UURemoteObjectError.decodeFailed("https://example.com/x")
        XCTAssertTrue(error.localizedDescription.contains("example.com"))
    }

    // MARK: Data specialization (default decode)

    func test_object_fetchesFromNetwork_whenNotCached() async throws
    {
        let key = objectKey("network")
        let payload = objectPayload(0x21)
        session.transportProvider = { request in
            ObjectTransport(data: payload, response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let result = try await sut.object(for: key)

        XCTAssertEqual(result, payload)
        XCTAssertEqual(session.requestCount, 1)
    }

    func test_object_storesToDiskAndMemory_afterDownload() async throws
    {
        let key = objectKey("store")
        let payload = objectPayload(0x31)
        session.transportProvider = { request in
            ObjectTransport(data: payload, response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        _ = try await sut.object(for: key)

        XCTAssertEqual(cache.storedData(for: key), payload)
        XCTAssertEqual(cache.dataWriteCount, 1)
        XCTAssertEqual(sut.memoryCachedObject(for: key), payload)
    }

    func test_object_returnsFromMemory_withoutDiskOrNetwork() async throws
    {
        let key = objectKey("memory")
        let payload = objectPayload(0x41)
        session.transportProvider = { request in
            ObjectTransport(data: payload, response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        _ = try await sut.object(for: key)
        let diskReadsAfterPrime = cache.dataReadCount

        let result = try await sut.object(for: key)

        XCTAssertEqual(result, payload)
        XCTAssertEqual(session.requestCount, 1)
        XCTAssertEqual(cache.dataReadCount, diskReadsAfterPrime)
    }

    func test_object_returnsFromDisk_whenMemoryEmpty() async throws
    {
        let key = objectKey("disk")
        let payload = objectPayload(0x51)
        cache.seed(payload, for: key)

        let result = try await sut.object(for: key)

        XCTAssertEqual(result, payload)
        XCTAssertEqual(session.requestCount, 0)
        XCTAssertEqual(cache.dataReadCount, 1)
        XCTAssertEqual(sut.memoryCachedObject(for: key), payload)
    }

    func test_clearMemoryCache_forcesDiskLookup() async throws
    {
        let key = objectKey("clear-memory")
        let payload = objectPayload(0x61)
        session.transportProvider = { request in
            ObjectTransport(data: payload, response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        _ = try await sut.object(for: key)
        sut.clearMemoryCache()

        _ = try await sut.object(for: key)
        XCTAssertEqual(session.requestCount, 1)
    }

    // MARK: Coalescing

    func test_concurrentRequests_sameUrl_coalesceToSingleFetch() async throws
    {
        let key = objectKey("coalesce")
        let payload = objectPayload(0x71)
        let gate = ObjectGate()
        await gate.block()

        session.transportProvider = { request in
            await gate.waitIfBlocking()
            return ObjectTransport(data: payload, response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let sut = self.sut!
        let tasks = (0..<20).map { _ in Task { try await sut.object(for: key) } }

        try await waitUntil { self.session.requestCount == 1 }
        await gate.release()

        for task in tasks
        {
            let value = try await task.value
            XCTAssertEqual(value, payload)
        }

        XCTAssertEqual(session.requestCount, 1)
        XCTAssertEqual(cache.dataWriteCount, 1)
    }

    // MARK: Cancellation

    func test_cancellation_inFlight_throwsCancellationError() async throws
    {
        let key = objectKey("cancel")
        let gate = ObjectGate()
        await gate.block()

        session.transportProvider = { request in
            await gate.waitIfBlocking()
            return ObjectTransport(data: objectPayload(), response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let sut = self.sut!
        let task = Task { () -> Result<Data, Error> in
            do { return .success(try await sut.object(for: key)) }
            catch { return .failure(error) }
        }

        try await waitUntil { self.session.requestCount == 1 }
        task.cancel()
        await gate.release()

        let result = await task.value
        switch result
        {
            case .success:
                XCTFail("Expected cancellation")

            case .failure(let error):
                XCTAssertTrue(error is CancellationError)
        }
    }

    // MARK: Errors

    func test_object_throwsInvalidUrl_forUnparseableKey() async throws
    {
        do
        {
            _ = try await sut.object(for: "")
            XCTFail("Expected invalidUrl")
        }
        catch let error as UURemoteObjectError
        {
            guard case .invalidUrl = error else
            {
                return XCTFail("Expected invalidUrl, got \(error)")
            }
        }

        XCTAssertEqual(session.requestCount, 0)
    }

    func test_object_throwsEmptyResponse_onEmptyBody() async throws
    {
        let key = objectKey("empty")
        session.transportProvider = { request in
            ObjectTransport(data: Data(), response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        do
        {
            _ = try await sut.object(for: key)
            XCTFail("Expected emptyResponse")
        }
        catch let error as UURemoteObjectError
        {
            guard case .emptyResponse = error else
            {
                return XCTFail("Expected emptyResponse, got \(error)")
            }
        }
    }

    func test_object_throwsHttpError_onNonSuccessStatus() async throws
    {
        let key = objectKey("http-error")
        session.transportProvider = { request in
            ObjectTransport(data: Data("nope".utf8), response: objectHttpResponse(url: request.url, statusCode: 404), error: nil)
        }

        do
        {
            _ = try await sut.object(for: key)
            XCTFail("Expected HTTP error")
        }
        catch
        {
            XCTAssertEqual(error.uuHttpStatusCode, 404)
        }

        XCTAssertNil(cache.storedData(for: key))
    }

    // MARK: Pipeline hooks

    func test_transformHook_isAppliedBeforePersist() async throws
    {
        let key = objectKey("transform")
        let payload = objectPayload(0x81)
        let suffix = Data([0xFF])

        let session = ObjectMockSession()
        session.transportProvider = { request in
            ObjectTransport(data: payload, response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }
        let cache = ObjectMockDataCache()
        let api = ObjectMockApi(mockSession: session)
        let transforming = TransformingObject(suffix: suffix, dataCache: cache, remoteApi: api)

        let result = try await transforming.object(for: key)

        XCTAssertEqual(result, payload + suffix)
        XCTAssertEqual(cache.storedData(for: key), payload + suffix)
    }

    func test_additionalMetadata_isMergedIntoDiskCache() async throws
    {
        let key = objectKey("metadata")
        let payload = objectPayload(0x91)

        let session = ObjectMockSession()
        session.transportProvider = { request in
            ObjectTransport(data: payload, response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }
        let cache = ObjectMockDataCache()
        let api = ObjectMockApi(mockSession: session)
        let annotated = MetadataObject(dataCache: cache, remoteApi: api)

        _ = try await annotated.object(for: key)

        let meta = cache.storedMetaData(for: key)
        XCTAssertEqual(meta["test.label"] as? String, "annotated")
        XCTAssertEqual(cache.metaWriteCount, 1)
    }

    func test_customDecode_decodesNonDataValueType() async throws
    {
        let key = objectKey("string-decode")
        let text = "hello-remote-object"
        let payload = Data(text.utf8)

        let session = ObjectMockSession()
        session.transportProvider = { request in
            ObjectTransport(data: payload, response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }
        let cache = ObjectMockDataCache()
        let api = ObjectMockApi(mockSession: session)
        let stringLoader = StringObject(dataCache: cache, remoteApi: api)

        let result = try await stringLoader.object(for: key)

        XCTAssertEqual(result, text)
        XCTAssertEqual(stringLoader.memoryCachedObject(for: key), text)
        XCTAssertEqual(cache.storedData(for: key), payload)
    }

    func test_customDecode_throwsDecodeFailed_onBadBytes() async throws
    {
        let key = objectKey("decode-failed")
        session.transportProvider = { request in
            ObjectTransport(data: Data([0xFF, 0xFE, 0xFD]), response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let cache = ObjectMockDataCache()
        let api = ObjectMockApi(mockSession: session)
        let stringLoader = StringObject(dataCache: cache, remoteApi: api)

        do
        {
            _ = try await stringLoader.object(for: key)
            XCTFail("Expected decodeFailed")
        }
        catch let error as UURemoteObjectError
        {
            guard case .decodeFailed = error else
            {
                return XCTFail("Expected decodeFailed, got \(error)")
            }
        }
    }

    // MARK: Remote API & response handler

    func test_api_prepareRequest_installsResponseHandler() async throws
    {
        let api = UURemoteObjectApi()
        let request = UUHttpRequest(url: objectKey("api-prepare"))

        await api.prepareRequest(request)

        XCTAssertTrue(request.responseHandler is UURemoteObjectResponseHandler)
    }

    func test_api_makeResponseHandler_isOverridable() async throws
    {
        let api = CustomObjectApi()
        let request = UUHttpRequest(url: objectKey("api-custom"))

        await api.prepareRequest(request)

        XCTAssertTrue(request.responseHandler is CustomObjectResponseHandler)
    }

    func test_api_executeRequest_parsesThroughInstalledHandler() async throws
    {
        let key = objectKey("api-execute")
        let payload = objectPayload(0xB1)
        let session = ObjectMockSession()
        session.transportProvider = { request in
            ObjectTransport(data: payload, response: objectHttpResponse(url: request.url, statusCode: 200), error: nil)
        }
        let api = ObjectMockApi(mockSession: session)

        let response = await api.executeRequest(UUHttpRequest(url: key))

        XCTAssertNil(response.httpError)
        XCTAssertEqual(response.parsedResponse as? Data, payload)
        XCTAssertEqual(session.requestCount, 1)
    }

    func test_responseHandler_parsesBinaryData_onSuccess() async throws
    {
        let key = objectKey("handler-success")
        let payload = objectPayload(0xC1)

        let request = UUHttpRequest(url: key)
        request.httpRequest = await request.buildURLRequest()

        let handler = UURemoteObjectResponseHandler()
        let response = await handler.handleResponse(
            request: request,
            data: payload,
            response: objectHttpResponse(url: key, statusCode: 200),
            error: nil)

        XCTAssertNil(response.httpError)
        XCTAssertEqual(response.parsedResponse as? Data, payload)
    }

    func test_responseHandler_setsHttpError_onNonSuccess() async throws
    {
        let key = objectKey("handler-error")

        let request = UUHttpRequest(url: key)
        request.httpRequest = await request.buildURLRequest()

        let handler = UURemoteObjectResponseHandler()
        let response = await handler.handleResponse(
            request: request,
            data: Data("nope".utf8),
            response: objectHttpResponse(url: key, statusCode: 404),
            error: nil)

        XCTAssertNotNil(response.httpError)
        XCTAssertEqual(response.httpStatusCode, 404)
    }
}

// MARK: - Subclasses under test

private final class TransformingObject: UURemoteObject<Data>, @unchecked Sendable
{
    private let suffix: Data

    init(suffix: Data, dataCache: UUDataCacheProtocol, remoteApi: UURemoteObjectApi)
    {
        self.suffix = suffix
        super.init(dataCache: dataCache, remoteApi: remoteApi)
    }

    override func transform(downloadedData data: Data, for url: String) async throws -> Data
    {
        data + suffix
    }
}

private final class MetadataObject: UURemoteObject<Data>, @unchecked Sendable
{
    override init(dataCache: UUDataCacheProtocol, remoteApi: UURemoteObjectApi)
    {
        super.init(dataCache: dataCache, remoteApi: remoteApi)
    }

    override func additionalMetadata(for value: Data, data: Data, url: String) async -> [String: Any]
    {
        ["test.label": "annotated"]
    }
}

private final class StringObject: UURemoteObject<String>, @unchecked Sendable
{
    override init(dataCache: UUDataCacheProtocol, remoteApi: UURemoteObjectApi)
    {
        super.init(dataCache: dataCache, remoteApi: remoteApi)
    }

    override func decode(_ data: Data, for url: String) async throws -> String
    {
        guard let text = String(data: data, encoding: .utf8) else
        {
            throw UURemoteObjectError.decodeFailed(url)
        }

        return text
    }

    override func cost(for value: String) -> Int
    {
        value.utf8.count
    }
}

private final class CustomObjectResponseHandler: UURemoteObjectResponseHandler
{
}

private final class CustomObjectApi: UURemoteObjectApi, @unchecked Sendable
{
    override func makeResponseHandler() -> UUHttpResponseHandler
    {
        CustomObjectResponseHandler()
    }
}
