//
//  LiveRemoteApiTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
import Testing
import UUSwiftCore
import UUSwiftTestCore
@testable import UUSwiftNetworking

/// Live integration tests for ``UURemoteApi`` via ``TestApi`` and the PHP `TestController`.
final class LiveRemoteApiTests: BaseOnlineTest
{
    private static let defaultId = "12345"
    private static let defaultName = "IntegrationTest"
    private static let defaultData = "This is for live integration testing between mobile libraries and real servers."

    private static let defaultApiObject = TestApiObject(
        id: defaultId,
        name: defaultName,
        data: defaultData
    )

    override func tearDown()
    {
        super.tearDown()
        Thread.sleep(forTimeInterval: 0.1)
    }

    private func testApi() throws -> TestApi
    {
        let cfg = try loadTestConfig()
        return TestApi(baseUrl: cfg.testApiUrl, session: uuHttpSessionForTest)
    }

    // MARK: - Tests

    func test_0000_getObject() async throws
    {
        let api = try testApi()
        let result = await api.getObject(nil)

        let success = try XCTUnwrap(result.get())
        UULog.debug(tag: "LiveRemoteApiTests", message: "test_0000_getObject, Response: \(success)")
        assertReply(expectedSuccess: Self.defaultApiObject, response: success)
    }

    func test_0002_getObjectWithOverrides() async throws
    {
        let api = try testApi()
        let override = TestApiObject(id: "one", name: "two", data: "three")
        let result = await api.getObject(override)

        let success = try XCTUnwrap(result.get())
        UULog.debug(tag: "LiveRemoteApiTests", message: "test_0002_getObjectWithOverrides, Response: \(success)")
        assertReply(expectedSuccess: override, response: success)
    }

    func test_0003_getArray() async throws
    {
        let api = try testApi()
        let count = 7
        let result = await api.getArray(count: count)

        let success = try XCTUnwrap(result.get())
        UULog.debug(tag: "LiveRemoteApiTests", message: "test_0003_getArray, Response: \(success)")
        assertArrayReply(expectedResponseCount: count, response: success)
    }

    func test_0004_postObject() async throws
    {
        let api = try testApi()
        let post = TestApiObject(id: "one", name: "two", data: "three")
        let result = await api.postObject(post)

        let success = try XCTUnwrap(result.get())
        UULog.debug(tag: "LiveRemoteApiTests", message: "test_0004_postObject, Response: \(success)")
        assertReply(expectedSuccess: post, response: success)
    }

    func test_0005_postList() async throws
    {
        let api = try testApi()
        let post = [
            TestApiObject(id: "one", name: "two", data: "three"),
            TestApiObject(id: "A", name: "B", data: "C"),
            TestApiObject(id: "Foo", name: "Bar", data: "Baz"),
        ]
        let result = await api.postArray(post)

        let success = try XCTUnwrap(result.get())
        UULog.debug(tag: "LiveRemoteApiTests", message: "test_0005_postList, Response: \(success)")
        XCTAssertEqual(success.count, post.count)
        XCTAssertEqual(success, post)
    }

    // MARK: - Assertions

    private func assertReply(expectedSuccess: TestApiObject?, response: TestApiObject)
    {
        XCTAssertEqual(response, expectedSuccess)
    }

    private func assertArrayReply(expectedResponseCount: Int, response: [TestApiObject])
    {
        XCTAssertEqual(response.count, expectedResponseCount)
        for (index, item) in response.enumerated()
        {
            XCTAssertEqual(item.id, "\(index)")
            XCTAssertEqual(item.name, "Name-\(index)")
            XCTAssertEqual(item.data, "Data for object \(index)")
        }
    }
}

// MARK: - Result helpers

private extension Result
{
    func get() throws -> Success where Failure == Error
    {
        switch self
        {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
        }
    }
}
