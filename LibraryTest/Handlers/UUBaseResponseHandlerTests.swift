//
//  UUBaseResponseHandlerTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
import UUSwiftTestCore
@testable import UUSwiftNetworking

final class UUBaseResponseHandlerTests: XCTestCase
{
    private var handler: UUPassthroughResponseHandler!
    private var request: UUHttpRequest!

    override func setUp()
    {
        super.setUp()
        handler = UUPassthroughResponseHandler()
        request = HandlerTestSupport.uuRequest()
    }

    func test_parsesBodyWithSuccessParser() async
    {
        let body = Data("payload".utf8)
        let response = HandlerTestSupport.httpResponse(statusCode: 200)

        let result = await handler.handleResponse(
            request: request,
            data: body,
            response: response,
            error: nil
        )

        XCTAssertNil(result.httpError)
        XCTAssertEqual(result.parsedResponse as? Data, body)
    }

    func test_maps404ToHttpError() async
    {
        let body = Data("not found".utf8)
        let response = HandlerTestSupport.httpResponse(statusCode: 404)

        let result = await handler.handleResponse(
            request: request,
            data: body,
            response: response,
            error: nil
        )

        XCTAssertEqual(result.httpError?.uuHttpErrorCode, .httpError)
        XCTAssertEqual(result.parsedResponse as? Data, body)
    }

    func test_maps401ToAuthorizationNeeded() async
    {
        let body = Data(#"{"message":"unauthorized"}"#.utf8)
        let response = HandlerTestSupport.httpResponse(
            statusCode: 401,
            contentType: UUContentType.applicationJson
        )

        let result = await handler.handleResponse(
            request: request,
            data: body,
            response: response,
            error: nil
        )

        XCTAssertEqual(result.httpError?.uuHttpErrorCode, .authorizationNeeded)
        XCTAssertEqual(result.httpError?.uuHttpStatusCode, 401)
    }

    func test_usesErrorParserForNonSuccessStatus() async
    {
        let successParser = CountingLabelParser(label: "success")
        let errorParser = CountingLabelParser(label: "error-body")
        let customHandler = HandlerTestSupport.handler(success: successParser, error: errorParser)
        let body = Data("err".utf8)
        let response = HandlerTestSupport.httpResponse(statusCode: 500)

        let result = await customHandler.handleResponse(
            request: request,
            data: body,
            response: response,
            error: nil
        )

        XCTAssertEqual(successParser.parseCallCount, 0)
        XCTAssertEqual(errorParser.parseCallCount, 1)
        XCTAssertEqual(result.parsedResponse as? String, "error-body")
        XCTAssertNotNil(result.httpError)
    }

    func test_honorsErrorReturnedFromParser() async
    {
        let injectedError = UUErrorFactory.createError(.httpFailure, ["test": true])
        let customHandler = HandlerTestSupport.handler(
            success: ErrorInjectingParser(error: injectedError),
            error: UUBinaryDataParser()
        )
        let response = HandlerTestSupport.httpResponse(statusCode: 200)

        let result = await customHandler.handleResponse(
            request: request,
            data: Data("{}".utf8),
            response: response,
            error: nil
        )

        XCTAssertTrue(result.httpError as AnyObject === injectedError as AnyObject)
        XCTAssertNil(result.parsedResponse)
    }

    func test_wrapsTransportError() async
    {
        enum TestTransportError: Error { case offline }
        let result = await handler.handleResponse(
            request: request,
            data: nil,
            response: nil,
            error: TestTransportError.offline
        )

        XCTAssertEqual(result.httpError?.uuHttpErrorCode, .httpFailure)
    }

    func test_defaultMimeTypeHandlerUsesMimeTypeDataParser() async
    {
        let baseHandler = UUBaseResponseHandler()
        XCTAssertTrue(baseHandler.successParser is UUMimeTypeDataParser)
        XCTAssertTrue(baseHandler.errorParser is UUMimeTypeDataParser)
    }

    func test_emptyBodySkipsParsing() async
    {
        let response = HandlerTestSupport.httpResponse(statusCode: 200)

        let result = await handler.handleResponse(
            request: request,
            data: Data(),
            response: response,
            error: nil
        )

        XCTAssertNil(result.httpError)
        XCTAssertNil(result.parsedResponse)
    }
}

private final class CountingLabelParser: UUHttpDataParser
{
    let label: String
    private(set) var parseCallCount = 0

    init(label: String)
    {
        self.label = label
    }

    func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
    {
        parseCallCount += 1
        return label
    }
}

private final class ErrorInjectingParser: UUHttpDataParser
{
    let error: Error

    init(error: Error)
    {
        self.error = error
    }

    func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
    {
        error
    }
}
