//
//  UUTextDataParserTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUTextDataParserTests: XCTestCase
{
    private var parser: UUTextDataParser!

    override func setUp()
    {
        super.setUp()
        parser = UUTextDataParser()
    }

    func test_decodesUtf8Text() async
    {
        let result = await parse("Hello, world!")

        XCTAssertEqual(result as? String, "Hello, world!")
    }

    func test_decodesUnicodeText() async
    {
        let text = "銀虎 🐯 snow 雪"
        let result = await parse(text)

        XCTAssertEqual(result as? String, text)
    }

    func test_decodesMultilineText() async
    {
        let text = "line one\nline two\r\nline three"
        let result = await parse(text)

        XCTAssertEqual(result as? String, text)
    }

    func test_emptyDataReturnsEmptyString() async
    {
        let result = await parse(Data())

        XCTAssertEqual(result as? String, "")
    }

    func test_decodesJsonAsPlainText() async
    {
        let json = #"{"id":"abc","count":7}"#
        let result = await parse(json)

        XCTAssertEqual(result as? String, json)
    }

    private func parse(_ text: String) async -> Any?
    {
        await parse(Data(text.utf8))
    }

    private func parse(_ data: Data) async -> Any?
    {
        await parser.parse(
            data: data,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.textPlain),
            request: ParserTestSupport.urlRequest()
        )
    }
}
