//
//  UURemoteApiTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
@testable import UUSwiftNetworking

// MARK: - Shared test fixtures (file scope avoids capturing XCTestCase in closures)

private let remoteApiTestRequestUrl = "https://api.example.com/resource"

private func remoteApiTestRequest() -> UUHttpRequest
{
    UUHttpRequest(url: remoteApiTestRequestUrl)
}

private func remoteApiSuccessResponse(request: UUHttpRequest, body: Any? = "ok") -> UUHttpResponse
{
    UUHttpResponse(request: request, parsedResponse: body)
}

private func remoteApiAuthNeededResponse(request: UUHttpRequest) -> UUHttpResponse
{
    UUHttpResponse(
        request: request,
        error: UUErrorFactory.createError(.authorizationNeeded, nil)
    )
}

private func assertSameErrorInstance(_ response: UUHttpResponse, _ expected: Error, file: StaticString = #filePath, line: UInt = #line)
{
    XCTAssertTrue(
        response.httpError as AnyObject === expected as AnyObject,
        "Expected the same error instance",
        file: file,
        line: line
    )
}

private final class ExecuteCounter: @unchecked Sendable
{
    private let lock = NSLock()
    private var count = 0

    @discardableResult
    func increment() -> Int
    {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }

    var value: Int
    {
        lock.lock()
        defer { lock.unlock() }
        return count
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

final class UURemoteApiTests: XCTestCase
{
    // MARK: - Test doubles

    private final class TestRemoteApi: UURemoteApi, @unchecked Sendable
    {
        private let stateLock = NSLock()
        private var _renewCallCount = 0
        private var renewStartedContinuations: [CheckedContinuation<Void, Never>] = []
        private var releaseRenewalContinuation: CheckedContinuation<Void, Never>?

        let testSession = TestHttpSession()

        var apiAuthorizationNeeded = false
        var renewResult = UURenewAuthorizationResponse(didAttempt: true, error: nil)
        /// Delay after optional release gate, in milliseconds.
        var renewDelayMs: UInt64 = 50
        var blockRenewalUntilReleased = false

        var executeRequestHandler: (UUHttpRequest) async -> UUHttpResponse
        {
            get { testSession.executeRequestHandler }
            set { testSession.executeRequestHandler = newValue }
        }

        override init()
        {
            super.init()
            session = testSession
        }

        var renewCallCount: Int
        {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _renewCallCount
        }

        func awaitRenewStarted(timeoutSeconds: TimeInterval = 5) async throws
        {
            let deadline = Date().addingTimeInterval(timeoutSeconds)
            while renewCallCount == 0
            {
                if Date() > deadline
                {
                    throw RenewalTestError.renewNotStartedInTime
                }
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        }

        func awaitRenewCoalescedWaiter(timeoutSeconds: TimeInterval = 5) async throws
        {
            let deadline = Date().addingTimeInterval(timeoutSeconds)
            while await renewalCoalescedWaiterCount() == 0
            {
                if Date() > deadline
                {
                    throw RenewalTestError.coalescedWaiterNotJoinedInTime
                }
                await Task.yield()
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        }

        func releaseBlockedRenewal()
        {
            stateLock.lock()
            let release = releaseRenewalContinuation
            releaseRenewalContinuation = nil
            stateLock.unlock()
            release?.resume()
        }

        public override func isApiAuthorizationNeeded() async -> Bool
        {
            apiAuthorizationNeeded
        }

        private func storeReleaseWaiter(_ continuation: CheckedContinuation<Void, Never>)
        {
            stateLock.lock()
            releaseRenewalContinuation = continuation
            stateLock.unlock()
        }

        private func recordRenewStart()
        {
            stateLock.lock()
            _renewCallCount += 1
            let waiters = renewStartedContinuations
            renewStartedContinuations.removeAll()
            stateLock.unlock()

            for waiter in waiters
            {
                waiter.resume()
            }
        }

        public override func renewApiAuthorization() async -> UURenewAuthorizationResponse
        {
            recordRenewStart()

            if blockRenewalUntilReleased
            {
                await withCheckedContinuation
                { continuation in
                    storeReleaseWaiter(continuation)
                }
            }

            if renewDelayMs > 0
            {
                try? await Task.sleep(nanoseconds: renewDelayMs * 1_000_000)
            }

            return renewResult
        }
    }

    private enum RenewalTestError: LocalizedError
    {
        case renewNotStartedInTime
        case coalescedWaiterNotJoinedInTime

        var errorDescription: String?
        {
            switch self
            {
                case .renewNotStartedInTime:
                    "renewApiAuthorization was not started in time"
                case .coalescedWaiterNotJoinedInTime:
                    "A coalesced renewal waiter did not join in time"
            }
        }
    }

    // MARK: - prepareRequest

    func test_prepareRequest_assignsApiAuthorizationProviderWhenRequestHasNone() async
    {
        let provider = UUBasicAuthorizationProvider(userName: "user", password: "pass")
        let request = remoteApiTestRequest()
        let api = TestRemoteApi()
        api.authorizationProvider = provider

        await api.prepareRequest(request)

        XCTAssertTrue(request.authorizationProvider === provider)
    }

    func test_prepareRequest_doesNotReplaceExistingRequestAuthorizationProvider() async
    {
        let apiProvider = UUBasicAuthorizationProvider(userName: "api", password: "api")
        let requestProvider = UUBasicAuthorizationProvider(userName: "req", password: "req")
        let request = remoteApiTestRequest()
        request.authorizationProvider = requestProvider
        let api = TestRemoteApi()
        api.authorizationProvider = apiProvider

        await api.prepareRequest(request)

        XCTAssertTrue(request.authorizationProvider === requestProvider)
    }

    // MARK: - Proactive renewal

    func test_proactiveRenewal_skipsRenewalWhenAuthorizationIsNotNeeded() async
    {
        let request = remoteApiTestRequest()
        let executeCount = ExecuteCounter()
        let api = TestRemoteApi()
        api.executeRequestHandler =
        { req in
            executeCount.increment()
            return remoteApiSuccessResponse(request: req)
        }

        let response = await api.executeRequest(request)

        XCTAssertEqual(response.parsedResponse as? String, "ok")
        XCTAssertEqual(api.renewCallCount, 0)
        XCTAssertEqual(executeCount.value, 1)
    }

    func test_proactiveRenewal_returnsRenewalErrorWithoutExecutingRequest() async
    {
        let renewalError = UUErrorFactory.createError(.httpFailure, ["RenewalTest": true])
        let request = remoteApiTestRequest()
        let executeCount = ExecuteCounter()
        let api = TestRemoteApi()
        api.apiAuthorizationNeeded = true
        api.renewResult = UURenewAuthorizationResponse(didAttempt: false, error: renewalError)
        api.executeRequestHandler =
        { req in
            executeCount.increment()
            return remoteApiSuccessResponse(request: req)
        }

        let response = await api.executeRequest(request)

        assertSameErrorInstance(response, renewalError)
        XCTAssertEqual(api.renewCallCount, 1)
        XCTAssertEqual(executeCount.value, 0)
    }

    func test_proactiveRenewal_coalescesConcurrentProactiveRenewalsIntoOneCall() async
    {
        let request = remoteApiTestRequest()
        let executeCount = ExecuteCounter()
        let api = TestRemoteApi()
        api.apiAuthorizationNeeded = true
        api.renewDelayMs = 150
        api.executeRequestHandler =
        { req in
            executeCount.increment()
            return remoteApiSuccessResponse(request: req)
        }

        await withTaskGroup(of: Void.self)
        { group in
            for _ in 0..<8
            {
                group.addTask
                {
                    _ = await api.executeRequest(request)
                }
            }
            for await _ in group { }
        }

        XCTAssertEqual(api.renewCallCount, 1)
        XCTAssertEqual(executeCount.value, 8)
    }

    // MARK: - Reactive renewal

    func test_reactiveRenewal_retriesOnceAfterAuthorizationNeededErrorAndSuccessfulRenewal() async
    {
        let request = remoteApiTestRequest()
        let executeCount = ExecuteCounter()
        let api = TestRemoteApi()
        api.executeRequestHandler =
        { req in
            if executeCount.increment() == 1
            {
                return remoteApiAuthNeededResponse(request: req)
            }
            return remoteApiSuccessResponse(request: req, body: "after-renew")
        }

        let response = await api.executeRequest(request)

        XCTAssertEqual(response.parsedResponse as? String, "after-renew")
        XCTAssertNil(response.httpError)
        XCTAssertEqual(api.renewCallCount, 1)
        XCTAssertEqual(executeCount.value, 2)
    }

    func test_reactiveRenewal_returnsRenewalErrorInsteadOfOriginalAuthErrorWhenReactiveRenewFails() async
    {
        let renewalError = UUErrorFactory.createError(.httpFailure, ["ReactiveRenewFailed": true])
        let request = remoteApiTestRequest()
        let executeCount = ExecuteCounter()
        let api = TestRemoteApi()
        api.renewResult = UURenewAuthorizationResponse(didAttempt: true, error: renewalError)
        api.executeRequestHandler =
        { req in
            executeCount.increment()
            return remoteApiAuthNeededResponse(request: req)
        }

        let response = await api.executeRequest(request)

        assertSameErrorInstance(response, renewalError)
        XCTAssertEqual(api.renewCallCount, 1)
        XCTAssertEqual(executeCount.value, 1)
    }

    func test_reactiveRenewal_doesNotRetryRequestWhenRenewalReturnsDidAttemptFalse() async
    {
        let request = remoteApiTestRequest()
        let executeCount = ExecuteCounter()
        let api = TestRemoteApi()
        api.renewResult = UURenewAuthorizationResponse(didAttempt: false, error: nil)
        api.executeRequestHandler =
        { req in
            executeCount.increment()
            return remoteApiAuthNeededResponse(request: req)
        }

        let response = await api.executeRequest(request)

        XCTAssertNotNil(response.httpError)
        XCTAssertEqual(response.httpError?.uuHttpErrorCode, .authorizationNeeded)
        XCTAssertEqual(api.renewCallCount, 1)
        XCTAssertEqual(executeCount.value, 1)
    }

    func test_reactiveRenewal_coalescesConcurrentReactiveRenewalsAfterAuthErrors() async
    {
        let request = remoteApiTestRequest()
        let api = TestRemoteApi()
        api.renewDelayMs = 150
        api.executeRequestHandler =
        { req in
            remoteApiAuthNeededResponse(request: req)
        }

        await withTaskGroup(of: Void.self)
        { group in
            for _ in 0..<6
            {
                group.addTask
                {
                    _ = await api.executeRequest(request)
                }
            }
            for await _ in group { }
        }

        XCTAssertEqual(api.renewCallCount, 1)
    }

    // MARK: - Renewal sequencing

    func test_renewalSequencing_startsNewRenewalAfterPreviousInFlightRenewalCompletes() async
    {
        let request = remoteApiTestRequest()
        let api = TestRemoteApi()
        api.apiAuthorizationNeeded = true
        api.executeRequestHandler =
        { req in
            remoteApiSuccessResponse(request: req)
        }

        _ = await api.executeRequest(request)
        XCTAssertEqual(api.renewCallCount, 1)

        _ = await api.executeRequest(request)
        XCTAssertEqual(api.renewCallCount, 2)
    }

    func test_renewalSequencing_lateWaiterJoinsInFlightRenewalInsteadOfStartingAnother() async throws
    {
        let request = remoteApiTestRequest()
        let api = TestRemoteApi()
        api.apiAuthorizationNeeded = true
        api.blockRenewalUntilReleased = true
        api.executeRequestHandler =
        { req in
            remoteApiSuccessResponse(request: req)
        }

        let first: Task<Void, Never> = Task
        {
            _ = await api.executeRequest(request)
        }
        await Task.yield()
        try await api.awaitRenewStarted()

        let second: Task<Void, Never> = Task
        {
            _ = await api.executeRequest(request)
        }

        try await api.awaitRenewCoalescedWaiter()

        api.releaseBlockedRenewal()
        await first.value
        await second.value

        XCTAssertEqual(api.renewCallCount, 1)
    }
}
