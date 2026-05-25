//
//  UUJsonDataParserTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUJsonDataParserTests: XCTestCase
{
    private var parser: UUJsonDataParser!

    override func setUp()
    {
        super.setUp()
        parser = UUJsonDataParser()
    }

    func test_parsesJsonObject() async
    {
        let data = Data(#"{"id":"item-42","count":99}"#.utf8)
        let result = await parse(data)

        let dict = result as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["id"] as? String, "item-42")
        XCTAssertEqual(dict?["count"] as? Int, 99)
    }

    func test_parsesJsonArray() async
    {
        let data = Data(#"[1,2,3]"#.utf8)
        let result = await parse(data)

        let array = result as? [Any]
        XCTAssertEqual(array?.count, 3)
    }

    func test_malformedJsonReturnsNil() async
    {
        let result = await parse(Data("{not json".utf8))

        XCTAssertNil(result)
    }

    func test_emptyDataReturnsNil() async
    {
        let result = await parse(Data())

        XCTAssertNil(result)
    }

    private func parse(_ data: Data) async -> Any?
    {
        await parser.parse(
            data: data,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.applicationJson),
            request: ParserTestSupport.urlRequest()
        )
    }
}
