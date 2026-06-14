//
//  UURemoteImageV2Tests.swift
//  UUSwiftNetworking
//
//  Unit tests for UURemoteImageV2 and the generic UURemoteObject base (plus the shared remote API
//  and response handler). All behavior is verified with mocks; no live network or shared
//  singletons are used.
//

import XCTest
import CoreGraphics
import UUSwiftCore
@testable import UUSwiftNetworking

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Test Support

private enum ImageV2TestError: Error
{
    case timeout
}

private func imageV2Key(_ name: String) -> String
{
    "https://remote-image-v2-test.example.com/\(name)-\(UUID().uuidString).png"
}

/// Produces a valid, decodable PNG of the requested pixel dimensions.
private func makePngData(width: Int, height: Int) -> Data
{
    #if os(macOS)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0)!

    // Zero-fill the pixel buffer so the PNG round-trips cleanly (avoids "corrupt" decode warnings).
    if let pixels = rep.bitmapData
    {
        memset(pixels, 0, rep.bytesPerRow * rep.pixelsHigh)
    }

    return rep.representation(using: .png, properties: [:])!
    #else
    let size = CGSize(width: width, height: height)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.pngData
    { context in
        UIColor.red.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
    #endif
}

private func imageV2HttpResponse(url: String, statusCode: Int) -> HTTPURLResponse
{
    HTTPURLResponse(
        url: URL(string: url)!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: [UUHttpHeader.contentType: "image/png"])!
}

private actor ImageV2Gate
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

private struct ImageV2Transport: @unchecked Sendable
{
    let data: Data?
    let response: HTTPURLResponse?
    let error: Error?
}

/// A mock `UUHttpSession` that records calls and runs the request's installed response handler,
/// exercising the real parse pipeline end-to-end.
private final class ImageV2MockSession: UUHttpSession, @unchecked Sendable
{
    private let lock = NSLock()
    private var _requestCount = 0

    var transportProvider: @Sendable (UUHttpRequest) async -> ImageV2Transport =
    { request in
        ImageV2Transport(data: makePngData(width: 4, height: 4), response: imageV2HttpResponse(url: request.url, statusCode: 200), error: nil)
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

private final class ImageV2MockApi: UURemoteObjectApi, @unchecked Sendable
{
    let mockSession: ImageV2MockSession

    init(mockSession: ImageV2MockSession)
    {
        self.mockSession = mockSession
        super.init()
        session = mockSession
    }
}

/// A mock disk cache with read / write counters and metadata storage.
private final class ImageV2MockDataCache: UUDataCacheProtocol, @unchecked Sendable
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

final class UURemoteImageV2Tests: XCTestCase
{
    private var cache: ImageV2MockDataCache!
    private var session: ImageV2MockSession!
    private var api: ImageV2MockApi!
    private var sut: UURemoteImageV2!

    override func setUp() async throws
    {
        try await super.setUp()
        cache = ImageV2MockDataCache()
        session = ImageV2MockSession()
        api = ImageV2MockApi(mockSession: session)
        sut = UURemoteImageV2(dataCache: cache, remoteApi: api)
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
                throw ImageV2TestError.timeout
            }
            try await Task.sleep(nanoseconds: 3_000_000)
        }
    }

    private func serveImage(width: Int = 4, height: Int = 4, statusCode: Int = 200)
    {
        session.transportProvider = { request in
            ImageV2Transport(
                data: makePngData(width: width, height: height),
                response: imageV2HttpResponse(url: request.url, statusCode: statusCode),
                error: nil)
        }
    }

    // MARK: Network tier

    func test_image_fetchesAndDecodesFromNetwork() async throws
    {
        let key = imageV2Key("network")
        let payload = makePngData(width: 6, height: 6)
        session.transportProvider = { request in
            ImageV2Transport(data: payload, response: imageV2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        // Compare against a reference decode so the assertion is independent of the platform's
        // points-per-pixel scale.
        let expected = UUImage(data: payload)!.size

        let image = try await sut.image(for: key)

        XCTAssertEqual(image.size.width, expected.width, accuracy: 0.5)
        XCTAssertEqual(image.size.height, expected.height, accuracy: 0.5)
        XCTAssertEqual(session.requestCount, 1)
    }

    func test_image_storesBytesToDiskAndImageToMemory() async throws
    {
        let key = imageV2Key("store")
        serveImage()

        _ = try await sut.image(for: key)

        XCTAssertNotNil(cache.storedData(for: key), "Raw bytes should be persisted to disk")
        XCTAssertEqual(cache.dataWriteCount, 1, "Download should write bytes to disk once")
        XCTAssertNotNil(sut.cachedImage(for: key), "Decoded image should be in the memory cache")
    }

    func test_image_persistsDimensionMetadata() async throws
    {
        let key = imageV2Key("dimensions")
        let payload = makePngData(width: 8, height: 5)
        session.transportProvider = { request in
            ImageV2Transport(data: payload, response: imageV2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }
        let expected = UUImage(data: payload)!.size

        _ = try await sut.image(for: key)

        let size = await sut.imageSize(for: key)
        XCTAssertEqual(size?.width ?? 0, expected.width, accuracy: 0.5)
        XCTAssertEqual(size?.height ?? 0, expected.height, accuracy: 0.5)
    }

    // MARK: Memory tier

    func test_image_returnsFromMemory_withoutDiskOrNetwork() async throws
    {
        let key = imageV2Key("memory")
        serveImage()

        let first = try await sut.image(for: key)
        let diskReadsAfterPrime = cache.dataReadCount

        let second = try await sut.image(for: key)

        XCTAssertTrue(first === second, "Memory hit should return the same cached instance")
        XCTAssertEqual(session.requestCount, 1, "Memory hit must not trigger a network fetch")
        XCTAssertEqual(cache.dataReadCount, diskReadsAfterPrime, "Memory hit must not read the disk cache")
    }

    // MARK: Disk tier

    func test_image_decodesFromDisk_whenMemoryEmpty() async throws
    {
        let key = imageV2Key("disk")
        let payload = makePngData(width: 10, height: 10)
        cache.seed(payload, for: key)
        let expected = UUImage(data: payload)!.size

        let image = try await sut.image(for: key)

        XCTAssertEqual(image.size.width, expected.width, accuracy: 0.5)
        XCTAssertEqual(session.requestCount, 0, "Disk hit must not trigger a network fetch")
        XCTAssertEqual(cache.dataReadCount, 1, "Disk hit should read the disk cache once")
        XCTAssertNotNil(sut.cachedImage(for: key), "Disk hit should warm the memory cache")
    }

    func test_clearMemoryCache_forcesDiskDecode() async throws
    {
        let key = imageV2Key("clear-memory")
        serveImage()

        _ = try await sut.image(for: key)
        XCTAssertNotNil(sut.cachedImage(for: key))

        sut.clearMemoryCache()
        XCTAssertNil(sut.cachedImage(for: key))

        _ = try await sut.image(for: key)
        XCTAssertEqual(session.requestCount, 1, "Second fetch should be served by disk, not network")
    }

    // MARK: Coalescing

    func test_concurrentRequests_sameUrl_coalesceToSingleFetchAndDecode() async throws
    {
        let key = imageV2Key("coalesce")
        let gate = ImageV2Gate()
        await gate.block()

        session.transportProvider = { request in
            await gate.waitIfBlocking()
            return ImageV2Transport(data: makePngData(width: 4, height: 4), response: imageV2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let sut = self.sut!
        let tasks = (0..<20).map
        { _ in
            Task { try await sut.image(for: key) }
        }

        try await waitUntil { self.session.requestCount == 1 }
        await gate.release()

        var images: [UUImage] = []
        for task in tasks
        {
            images.append(try await task.value)
        }

        XCTAssertEqual(session.requestCount, 1, "Concurrent requests for the same URL must share one network fetch")
        XCTAssertEqual(cache.dataWriteCount, 1, "Coalesced download must persist exactly once")

        // All waiters receive the single decoded instance produced by the coalesced worker.
        let first = images.first
        XCTAssertNotNil(first)
        for image in images
        {
            XCTAssertTrue(image === first, "All coalesced waiters should receive the same decoded image")
        }
    }

    // MARK: Cancellation

    func test_cancellation_inFlight_throwsCancellationError() async throws
    {
        let key = imageV2Key("cancel")
        let gate = ImageV2Gate()
        await gate.block()

        session.transportProvider = { request in
            await gate.waitIfBlocking()
            return ImageV2Transport(data: makePngData(width: 4, height: 4), response: imageV2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        let sut = self.sut!
        let task = Task { () -> Result<UUImage, Error> in
            do { return .success(try await sut.image(for: key)) }
            catch { return .failure(error) }
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

    // MARK: Error handling

    func test_image_throwsInvalidUrl_forUnparseableKey() async throws
    {
        do
        {
            _ = try await sut.image(for: "")
            XCTFail("Expected invalidUrl error")
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

    func test_image_throwsHttpError_onNonSuccessStatus() async throws
    {
        let key = imageV2Key("http-error")
        session.transportProvider = { request in
            ImageV2Transport(data: Data("not found".utf8), response: imageV2HttpResponse(url: request.url, statusCode: 404), error: nil)
        }

        do
        {
            _ = try await sut.image(for: key)
            XCTFail("Expected HTTP error to be thrown")
        }
        catch
        {
            XCTAssertEqual(error.uuHttpStatusCode, 404)
        }

        XCTAssertNil(cache.storedData(for: key), "Failed download must not be cached")
    }

    func test_image_throwsEmptyResponse_onEmptyBody() async throws
    {
        let key = imageV2Key("empty")
        session.transportProvider = { request in
            ImageV2Transport(data: Data(), response: imageV2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        do
        {
            _ = try await sut.image(for: key)
            XCTFail("Expected emptyResponse error")
        }
        catch let error as UURemoteObjectError
        {
            guard case .emptyResponse = error else
            {
                return XCTFail("Expected emptyResponse, got \(error)")
            }
        }
    }

    func test_image_throwsDecodeFailed_onNonImageBytes() async throws
    {
        let key = imageV2Key("decode-failed")
        session.transportProvider = { request in
            ImageV2Transport(data: Data("this is definitely not an image".utf8), response: imageV2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }

        do
        {
            _ = try await sut.image(for: key)
            XCTFail("Expected decodeFailed error")
        }
        catch let error as UURemoteObjectError
        {
            guard case .decodeFailed = error else
            {
                return XCTFail("Expected decodeFailed, got \(error)")
            }
        }
    }

    // MARK: Generic base (UURemoteObject<Data>)

    func test_genericBase_defaultDecode_returnsRawData() async throws
    {
        let key = imageV2Key("base-data")
        let payload = Data([0x01, 0x02, 0x03, 0x04])

        let session = ImageV2MockSession()
        session.transportProvider = { request in
            ImageV2Transport(data: payload, response: imageV2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }
        let cache = ImageV2MockDataCache()
        let api = ImageV2MockApi(mockSession: session)
        let base = UURemoteObject<Data>(dataCache: cache, remoteApi: api)

        let result = try await base.object(for: key)

        XCTAssertEqual(result, payload)
        XCTAssertEqual(base.memoryCachedObject(for: key), payload)
        XCTAssertEqual(cache.storedData(for: key), payload)
    }

    func test_transformHook_isAppliedBeforeDecodeAndCache() async throws
    {
        let key = imageV2Key("transform")
        let payload = Data([0x10, 0x20])
        let suffix = Data([0x99])

        let session = ImageV2MockSession()
        session.transportProvider = { request in
            ImageV2Transport(data: payload, response: imageV2HttpResponse(url: request.url, statusCode: 200), error: nil)
        }
        let cache = ImageV2MockDataCache()
        let api = ImageV2MockApi(mockSession: session)
        let transforming = TransformingDataObject(suffix: suffix, dataCache: cache, remoteApi: api)

        let result = try await transforming.object(for: key)

        XCTAssertEqual(result, payload + suffix, "transform output should be returned")
        XCTAssertEqual(cache.storedData(for: key), payload + suffix, "transform output should be cached")
    }

    // MARK: Remote API & response handler

    func test_api_prepareRequest_installsResponseHandler() async throws
    {
        let api = UURemoteObjectApi()
        let request = UUHttpRequest(url: imageV2Key("api-prepare"))

        await api.prepareRequest(request)

        XCTAssertTrue(request.responseHandler is UURemoteObjectResponseHandler)
    }

    func test_api_makeResponseHandler_isOverridable() async throws
    {
        let api = CustomObjectApi()
        let request = UUHttpRequest(url: imageV2Key("api-custom"))

        await api.prepareRequest(request)

        XCTAssertTrue(request.responseHandler is CustomObjectResponseHandler)
    }

    func test_responseHandler_parsesBinaryData_onSuccess() async throws
    {
        let key = imageV2Key("handler-success")
        let payload = makePngData(width: 3, height: 3)

        let request = UUHttpRequest(url: key)
        request.httpRequest = await request.buildURLRequest()

        let handler = UURemoteObjectResponseHandler()
        let response = await handler.handleResponse(
            request: request,
            data: payload,
            response: imageV2HttpResponse(url: key, statusCode: 200),
            error: nil)

        XCTAssertNil(response.httpError)
        XCTAssertEqual(response.parsedResponse as? Data, payload)
    }
}

// MARK: - Subclasses under test

private final class TransformingDataObject: UURemoteObject<Data>, @unchecked Sendable
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
