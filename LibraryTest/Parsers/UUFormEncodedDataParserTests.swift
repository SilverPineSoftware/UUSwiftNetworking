//
//  UUFormEncodedDataParserTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUFormEncodedDataParserTests: XCTestCase
{
    private var parser: UUFormEncodedDataParser!

    override func setUp()
    {
        super.setUp()
        parser = UUFormEncodedDataParser()
    }

    func test_parsesUrlEncodedPairs() async
    {
        let body = Data("name=Ryan&count=42".utf8)
        let result = await parse(body)

        let dict = result as? [String: Any]
        XCTAssertEqual(dict?["name"] as? String, "Ryan")
        XCTAssertEqual(dict?["count"] as? String, "42")
    }

    func test_decodesPercentEncoding() async
    {
        let body = Data("q=hello%20world".utf8)
        let result = await parse(body)

        let dict = result as? [String: Any]
        XCTAssertEqual(dict?["q"] as? String, "hello world")
    }

    func test_ignoresSegmentsWithoutEquals() async
    {
        let body = Data("orphan&key=value".utf8)
        let result = await parse(body)

        let dict = result as? [String: Any]
        XCTAssertEqual(dict?.count, 1)
        XCTAssertEqual(dict?["key"] as? String, "value")
    }

    private func parse(_ data: Data) async -> Any?
    {
        await parser.parse(
            data: data,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.formEncoded),
            request: ParserTestSupport.urlRequest()
        )
    }
}
