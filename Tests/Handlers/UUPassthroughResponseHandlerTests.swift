//
//  UUPassthroughResponseHandlerTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUPassthroughResponseHandlerTests: XCTestCase
{
    func test_successAndErrorParsersAreBinary() async
    {
        let handler = UUPassthroughResponseHandler()
        XCTAssertTrue(handler.successParser is UUBinaryDataParser)
        XCTAssertTrue(handler.errorParser is UUBinaryDataParser)
    }

    func test_roundTripRawDataOnSuccess() async
    {
        let handler = UUPassthroughResponseHandler()
        let request = HandlerTestSupport.uuRequest()
        let body = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let httpResponse = HandlerTestSupport.httpResponse(statusCode: 200)

        let result = await handler.handleResponse(
            request: request,
            data: body,
            response: httpResponse,
            error: nil
        )

        XCTAssertNil(result.httpError)
        XCTAssertEqual(result.parsedResponse as? Data, body)
        XCTAssertEqual(result.rawResponse, body)
    }
}
