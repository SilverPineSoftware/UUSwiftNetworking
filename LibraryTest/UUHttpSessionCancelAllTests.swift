//
//  UUHttpSessionCancelAllTests.swift
//  UUSwiftNetworking
//
//  Exercises session-wide cancelAll() and Swift Task cancellation.
//

import XCTest
import UUSwiftTestCore
@testable import UUSwiftNetworking

private let cancelAllTestHost = "uu-cancel-all-test.local"

/// URLProtocol that stays open until the task is cancelled (or completes via `stopLoading`).
private final class HangingURLProtocol: URLProtocol
{
    private static let sync = NSLock()
    nonisolated(unsafe) private static var activeProtocols: [HangingURLProtocol] = []

    override class func canInit(with request: URLRequest) -> Bool
    {
        request.url?.host == cancelAllTestHost
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest
    {
        request
    }

    override func startLoading()
    {
        Self.sync.lock()
        Self.activeProtocols.append(self)
        Self.sync.unlock()
    }

    override func stopLoading()
    {
        Self.sync.lock()
        Self.activeProtocols.removeAll { $0 === self }
        Self.sync.unlock()

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCancelled,
            userInfo: [NSLocalizedDescriptionKey: "cancelled"])
        client?.urlProtocol(self, didFailWithError: error)
    }

    static var activeCount: Int
    {
        sync.lock()
        defer { sync.unlock() }
        return activeProtocols.count
    }
}

/// URLProtocol that returns a minimal JSON body immediately.
private final class ImmediateJSONURLProtocol: URLProtocol
{
    override class func canInit(with request: URLRequest) -> Bool
    {
        request.url?.host == cancelAllTestHost
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest
    {
        request
    }

    override func startLoading()
    {
        let body = Data("{\"ok\":true}".utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [UUHttpHeader.contentType: UUContentType.applicationJson])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading()
    {
    }
}

private func makeCancelAllTestSession(protocolClasses: [AnyClass]) -> UUHttpSession
{
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = protocolClasses
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 60
    return UUHttpSession(configuration: configuration)
}

private func hangingRequestURL(path: String = "/slow") -> String
{
    "https://\(cancelAllTestHost)\(path)"
}

final class UUHttpSessionCancelAllTests: XCTestCase
{
    // MARK: - cancelAll

    func test_cancelAll_cancelsInFlightRequest() async throws
    {
        let session = makeCancelAllTestSession(protocolClasses: [HangingURLProtocol.self])
        let request = UUHttpRequest(url: hangingRequestURL())
        let box = HttpResponseBox()

        await withTaskGroup(of: Void.self)
        { group in
            group.addTask
            {
                box.value = await session.execute(request)
            }
            group.addTask
            {
                await waitUntil(timeout: 2)
                {
                    HangingURLProtocol.activeCount > 0
                }
                session.cancelAll()
            }
            for await _ in group { }
        }

        let response = try XCTUnwrap(box.value)
        UUAssertResponseError(response, .userCancelled)
    }

    func test_cancelAll_cancelsMultipleInFlightRequests() async throws
    {
        let session = makeCancelAllTestSession(protocolClasses: [HangingURLProtocol.self])
        let box1 = HttpResponseBox()
        let box2 = HttpResponseBox()

        await withTaskGroup(of: Void.self)
        { group in
            group.addTask
            {
                box1.value = await session.execute(UUHttpRequest(url: hangingRequestURL(path: "/a")))
            }
            group.addTask
            {
                box2.value = await session.execute(UUHttpRequest(url: hangingRequestURL(path: "/b")))
            }
            group.addTask
            {
                await waitUntil(timeout: 2)
                {
                    HangingURLProtocol.activeCount >= 2
                }
                session.cancelAll()
            }
            for await _ in group { }
        }

        UUAssertResponseError(try XCTUnwrap(box1.value), .userCancelled)
        UUAssertResponseError(try XCTUnwrap(box2.value), .userCancelled)
    }

    func test_cancelAll_allowsSubsequentRequestToComplete() async throws
    {
        let hangingSession = makeCancelAllTestSession(protocolClasses: [HangingURLProtocol.self])
        let hungBox = HttpResponseBox()

        await withTaskGroup(of: Void.self)
        { group in
            group.addTask
            {
                hungBox.value = await hangingSession.execute(
                    UUHttpRequest(url: hangingRequestURL(path: "/hang")))
            }
            group.addTask
            {
                await waitUntil(timeout: 2)
                {
                    HangingURLProtocol.activeCount > 0
                }
                hangingSession.cancelAll()
            }
            for await _ in group { }
        }

        _ = hungBox.value

        let followUpSession = makeCancelAllTestSession(protocolClasses: [ImmediateJSONURLProtocol.self])
        let followUp = UUCodableHttpRequest<CancelAllOkResponse, UUEmptyCodable>(
            url: hangingRequestURL(path: "/ok"))
        let result = await followUpSession.executeTyped(followUp)

        switch result
        {
            case .success(let value):
                XCTAssertTrue(value.ok)
            case .failure(let error):
                XCTFail("Expected success after cancelAll, got \(error)")
        }
    }

    // MARK: - Task cancellation

    func test_taskCancel_returnsUserCancelled() async throws
    {
        let session = makeCancelAllTestSession(protocolClasses: [HangingURLProtocol.self])
        let request = UUHttpRequest(url: hangingRequestURL(path: "/task-cancel"))
        let box = HttpResponseBox()

        let work = Task
        {
            box.value = await session.execute(request)
        }

        await waitUntil(timeout: 2)
        {
            HangingURLProtocol.activeCount > 0
        }

        work.cancel()
        _ = await work.value

        let response = try XCTUnwrap(box.value)
        UUAssertResponseError(response, .userCancelled)
        UUAssertError(response.httpError, .userCancelled)
    }

    func test_taskCancel_executeCodableRequest_returnsUserCancelledFailure() async throws
    {
        let session = makeCancelAllTestSession(protocolClasses: [HangingURLProtocol.self])
        let request = UUCodableHttpRequest<CancelAllOkResponse, UUEmptyCodable>(
            url: hangingRequestURL(path: "/codable-cancel"))

        let work = Task
        {
            await session.executeTyped(request)
        }

        await waitUntil(timeout: 2)
        {
            HangingURLProtocol.activeCount > 0
        }

        work.cancel()

        let result = await work.value
        switch result
        {
            case .success:
                XCTFail("Expected cancellation failure")
            case .failure(let error):
                UUAssertError(error, .userCancelled)
        }
    }

    func test_taskCancel_onlyAffectsCancelledRequest() async throws
    {
        let session = makeCancelAllTestSession(protocolClasses: [HangingURLProtocol.self])
        let requestA = UUHttpRequest(url: hangingRequestURL(path: "/only-a"))
        let requestB = UUHttpRequest(url: hangingRequestURL(path: "/only-b"))
        let boxA = HttpResponseBox()
        let boxB = HttpResponseBox()

        let workA = Task { boxA.value = await session.execute(requestA) }
        let workB = Task { boxB.value = await session.execute(requestB) }

        await waitUntil(timeout: 2)
        {
            HangingURLProtocol.activeCount >= 2
        }

        workA.cancel()
        _ = await workA.value
        UUAssertResponseError(try XCTUnwrap(boxA.value), .userCancelled)

        XCTAssertGreaterThanOrEqual(HangingURLProtocol.activeCount, 1, "Other request should remain in flight")

        workB.cancel()
        _ = await workB.value
        UUAssertResponseError(try XCTUnwrap(boxB.value), .userCancelled)
    }
}

// MARK: - Helpers

private final class HttpResponseBox: @unchecked Sendable
{
    var value: UUHttpResponse?
}

private struct CancelAllOkResponse: Codable
{
    var ok: Bool
}

private func waitUntil(
    timeout: TimeInterval,
    pollInterval: TimeInterval = 0.05,
    condition: @escaping () -> Bool) async
{
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline
    {
        if condition()
        {
            return
        }
        try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
    }
    XCTFail("Timed out waiting for condition")
}
