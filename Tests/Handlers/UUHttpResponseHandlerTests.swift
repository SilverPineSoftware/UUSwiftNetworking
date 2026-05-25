//
//  UUHttpResponseHandlerTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUHttpResponseHandlerTests: XCTestCase
{
    func test_baseHandlerConformsToProtocol() async
    {
        let handler: UUHttpResponseHandler = UUBaseResponseHandler()
        XCTAssertTrue(handler.successParser is UUMimeTypeDataParser)
        XCTAssertTrue(handler.errorParser is UUMimeTypeDataParser)
    }

    func test_passthroughHandlerUsesBinaryParsers() async
    {
        let handler: UUHttpResponseHandler = UUPassthroughResponseHandler()
        XCTAssertTrue(handler.successParser is UUBinaryDataParser)
        XCTAssertTrue(handler.errorParser is UUBinaryDataParser)
    }

    func test_customHandlerReturnsResponseFromImplementation() async
    {
        let request = HandlerTestSupport.uuRequest()
        let response = HandlerTestSupport.httpResponse()
        let expected = UUHttpResponse(request: request, parsedResponse: "done")

        let handler = StubHandler(expected: expected)
        let result = await handler.handleResponse(
            request: request,
            data: nil,
            response: response,
            error: nil
        )

        XCTAssertTrue(result === expected)
    }
}

private final class StubHandler: UUHttpResponseHandler
{
    private let expected: UUHttpResponse

    init(expected: UUHttpResponse)
    {
        self.expected = expected
    }

    var successParser: UUHttpDataParser { UUBinaryDataParser() }
    var errorParser: UUHttpDataParser { UUBinaryDataParser() }

    func handleResponse(
        request: UUHttpRequest,
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) async -> UUHttpResponse
    {
        expected
    }
}
