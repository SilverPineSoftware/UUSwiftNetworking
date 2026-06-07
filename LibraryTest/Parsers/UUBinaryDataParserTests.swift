//
//  UUBinaryDataParserTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUBinaryDataParserTests: XCTestCase
{
    private var parser: UUBinaryDataParser!

    override func setUp()
    {
        super.setUp()
        parser = UUBinaryDataParser()
    }

    func test_readsSingleBytePayload() async
    {
        let payload = Data([0xAB])
        let result = await parse(payload)

        let data = result as? Data
        XCTAssertNotNil(data)
        XCTAssertEqual(data, payload)
    }

    func test_readsMultiBytePayload() async
    {
        let payload = Data("binary payload".utf8)
        let result = await parse(payload)

        XCTAssertEqual(result as? Data, payload)
    }

    func test_readsPayloadLargerThanTypicalBuffer() async
    {
        let payload = Data((0..<25_000).map { UInt8($0 % 256) })
        let result = await parse(payload)

        XCTAssertEqual(result as? Data, payload)
    }

    func test_emptyDataReturnsEmptyByteArray() async
    {
        let result = await parse(Data())

        XCTAssertNotNil(result)
        XCTAssertEqual(result as? Data, Data())
    }

    func test_preservesNullBytesInPayload() async
    {
        let payload = Data([0x00, 0x01, 0x00, 0xFF])
        let result = await parse(payload)

        XCTAssertEqual(result as? Data, payload)
    }

    func test_ignoresHttpResponseMetadata() async
    {
        let response = ParserTestSupport.httpResponse(url: "https://other.example.com/file.bin")
        let result = await parser.parse(
            data: Data("x".utf8),
            response: response,
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertEqual(result as? Data, Data("x".utf8))
    }

    private func parse(_ data: Data) async -> Any?
    {
        await parser.parse(
            data: data,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.binary),
            request: ParserTestSupport.urlRequest()
        )
    }
}
