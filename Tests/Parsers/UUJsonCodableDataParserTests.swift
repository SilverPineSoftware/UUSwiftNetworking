//
//  UUJsonCodableDataParserTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore
@testable import UUSwiftNetworking

final class UUJsonCodableDataParserTests: XCTestCase
{
    func test_decodeFailureReturnsParseError() async
    {
        let parser = UUJsonCodableDataParser<ParserTestCodable>()
        let hexData = "00AA".uuToHexData()
        XCTAssertNotNil(hexData)
        let data = hexData!
        let response = ParserTestSupport.httpResponse(contentType: UUContentType.applicationJson)
        let request = ParserTestSupport.urlRequest()

        let parsedResult = await parser.parse(data: data, response: response, request: request)

        XCTAssertNotNil(parsedResult)
        UUAssertError(parsedResult as? Error, .parseFailure)
    }

    func test_decodeSuccess() async
    {
        let parser = UUJsonCodableDataParser<ParserTestCodable>()
        let obj = ParserTestCodable(fieldOne: "HelloWorld", fieldTwo: 2021)
        let data = obj.jsonData()!
        let response = ParserTestSupport.httpResponse(contentType: UUContentType.applicationJson)
        let request = ParserTestSupport.urlRequest()

        let parsedResult = await parser.parse(data: data, response: response, request: request)

        XCTAssertNil(parsedResult as? Error)
        XCTAssertEqual(parsedResult as? ParserTestCodable, obj)
    }

    func test_decodeSuccess_withCustomJsonDecoder() async
    {
        let parser = UUJsonCodableDataParser<ParserTestCodable>()
        parser.jsonDecoder = JSONDecoder()

        let obj = ParserTestCodable(fieldOne: "HelloWorld", fieldTwo: 2021)
        let data = obj.jsonData()!
        let response = ParserTestSupport.httpResponse(contentType: UUContentType.applicationJson)
        let request = ParserTestSupport.urlRequest()

        let parsedResult = await parser.parse(data: data, response: response, request: request)

        XCTAssertEqual(parsedResult as? ParserTestCodable, obj)
    }

    func test_parsesJsonObjectIntoTargetType() async
    {
        let parser = UUJsonCodableDataParser<ParserTestPayload>()
        let body = Data(#"{"id":"item-42","count":99}"#.utf8)

        let result = await parser.parse(
            data: body,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.applicationJson),
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertEqual(result as? ParserTestPayload, ParserTestPayload(id: "item-42", count: 99))
    }

    func test_ignoresUnknownJsonKeys() async
    {
        let parser = UUJsonCodableDataParser<ParserTestPayload>()
        let body = Data(#"{"id":"x","count":1,"extra":"ignored"}"#.utf8)

        let result = await parser.parse(
            data: body,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.applicationJson),
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertEqual(result as? ParserTestPayload, ParserTestPayload(id: "x", count: 1))
    }

    func test_parsesMinimalJsonObject() async
    {
        let parser = UUJsonCodableDataParser<ParserTestPayload>()
        let body = Data(#"{"id":"","count":0}"#.utf8)

        let result = await parser.parse(
            data: body,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.applicationJson),
            request: ParserTestSupport.urlRequest()
        )

        XCTAssertEqual(result as? ParserTestPayload, ParserTestPayload())
    }

    func test_malformedJsonReturnsParseError() async
    {
        let parser = UUJsonCodableDataParser<ParserTestPayload>()
        let body = Data("{not json".utf8)

        let result = await parser.parse(
            data: body,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.applicationJson),
            request: ParserTestSupport.urlRequest()
        )

        UUAssertError(result as? Error, .parseFailure)
    }
}
