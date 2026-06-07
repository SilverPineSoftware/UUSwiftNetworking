//
//  UUMimeTypeDataParserTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUMimeTypeDataParserTests: XCTestCase
{
    private var parser: UUMimeTypeDataParser!

    override func setUp()
    {
        super.setUp()
        parser = UUMimeTypeDataParser()
    }

    func test_dispatchesJsonToJsonParser() async
    {
        let data = Data(#"{"ok":true}"#.utf8)
        let result = await parser.parse(
            data: data,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.applicationJson),
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertTrue(result is [String: Any])
    }

    func test_dispatchesPlainTextToTextParser() async
    {
        let result = await parser.parse(
            data: Data("plain".utf8),
            response: ParserTestSupport.httpResponse(contentType: UUContentType.textPlain),
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertEqual(result as? String, "plain")
    }

    func test_dispatchesOctetStreamToBinaryParser() async
    {
        let payload = Data([0x01, 0x02])
        let result = await parser.parse(
            data: payload,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.binary),
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertEqual(result as? Data, payload)
    }

    func test_unknownMimeTypeReturnsNil() async
    {
        let result = await parser.parse(
            data: Data("x".utf8),
            response: ParserTestSupport.httpResponse(contentType: "application/unknown"),
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertNil(result)
    }

    func test_missingContentTypeReturnsNil() async
    {
        let result = await parser.parse(
            data: Data("x".utf8),
            response: ParserTestSupport.httpResponse(contentType: nil),
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertNil(result)
    }

    func test_registerResponseHandlerOverridesMimeType() async
    {
        parser.registerResponseHandler(["application/custom"], UUTextDataParser())
        let result = await parser.parse(
            data: Data("custom-body".utf8),
            response: ParserTestSupport.httpResponse(contentType: "application/custom"),
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertEqual(result as? String, "custom-body")
    }
}
