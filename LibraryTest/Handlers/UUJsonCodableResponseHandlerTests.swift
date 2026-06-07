//
//  UUJsonCodableResponseHandlerTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUJsonCodableResponseHandlerTests: XCTestCase
{
    func test_wiresTypedCodableParsersForSuccessAndError() async
    {
        let handler = UUJsonCodableResponseHandler<ParserTestPayload, ParserTestPayload>()
        XCTAssertTrue(handler.successParser is UUJsonCodableDataParser<ParserTestPayload>)
        XCTAssertTrue(handler.errorParser is UUJsonCodableDataParser<ParserTestPayload>)
    }

    func test_deserializesSuccessBodyIntoSuccessType() async
    {
        let handler = UUJsonCodableResponseHandler<ParserTestPayload, ParserTestPayload>()
        let request = HandlerTestSupport.uuRequest()
        let body = Data(#"{"id":"typed-ok","count":3}"#.utf8)
        let httpResponse = HandlerTestSupport.httpResponse(
            statusCode: 200,
            contentType: UUContentType.applicationJson
        )

        let result = await handler.handleResponse(
            request: request,
            data: body,
            response: httpResponse,
            error: nil
        )

        XCTAssertNil(result.httpError)
        XCTAssertEqual(result.parsedResponse as? ParserTestPayload, ParserTestPayload(id: "typed-ok", count: 3))
    }

    func test_mapsNonSuccessStatusToNetworkError() async
    {
        let handler = UUJsonCodableResponseHandler<ParserTestPayload, ParserTestPayload>()
        let request = HandlerTestSupport.uuRequest()
        let body = Data(#"{"id":"api-error","count":0}"#.utf8)
        let httpResponse = HandlerTestSupport.httpResponse(
            statusCode: 400,
            contentType: UUContentType.applicationJson
        )

        let result = await handler.handleResponse(
            request: request,
            data: body,
            response: httpResponse,
            error: nil
        )

        XCTAssertEqual(result.httpError?.uuHttpErrorCode, .httpError)
        XCTAssertEqual(result.parsedResponse as? ParserTestPayload, ParserTestPayload(id: "api-error", count: 0))
    }

    func test_maps401ToAuthorizationNeeded() async
    {
        let handler = UUJsonCodableResponseHandler<ParserTestPayload, ParserTestPayload>()
        let request = HandlerTestSupport.uuRequest()
        let body = Data(#"{"id":"auth","count":0}"#.utf8)
        let httpResponse = HandlerTestSupport.httpResponse(
            statusCode: 401,
            contentType: UUContentType.applicationJson
        )

        let result = await handler.handleResponse(
            request: request,
            data: body,
            response: httpResponse,
            error: nil
        )

        XCTAssertEqual(result.httpError?.uuHttpErrorCode, .authorizationNeeded)
    }
}
