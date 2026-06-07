//
//  UUHttpBodyTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/19/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUHttpBodyTests: XCTestCase
{
    // MARK: - encode

    func test_encode_returnsStoredContentFromInitializer()
    {
        let payload = Data("hello".utf8)
        let body = UUHttpBody(contentType: UUContentType.textPlain, content: payload)

        XCTAssertEqual(body.encode(), payload)
    }

    func test_encode_returnsNilWhenNoContentProvided()
    {
        let body = UUHttpBody(contentType: UUContentType.textPlain, content: nil)

        XCTAssertNil(body.encode())
    }

    func test_encode_subclassCanOverrideEncode()
    {
        let body = NullEncodingHttpBody()

        XCTAssertNil(body.encode())
    }

    // MARK: - buildHeaders

    func test_buildHeaders_setsContentTypeAndContentLength()
    {
        let body = UUHttpBody(contentType: UUContentType.applicationJson, content: nil)

        let headers = body.buildHeaders(128)

        XCTAssertEqual(UUContentType.applicationJson, headers[UUHttpHeader.contentType] as? String)
        XCTAssertEqual(128, headers[UUHttpHeader.contentLength] as? Int)
        XCTAssertNil(headers[UUHttpHeader.contentEncoding])
    }

    func test_buildHeaders_includesContentEncodingWhenSet()
    {
        let body = UUHttpBody(
            contentType: UUContentType.textPlain,
            contentEncoding: "gzip",
            content: nil
        )

        let headers = body.buildHeaders(64)

        XCTAssertEqual("gzip", headers[UUHttpHeader.contentEncoding] as? String)
    }

    // MARK: - prepareToSend

    func test_prepareToSend_successReturnsBodyAndHeaders()
    {
        let payload = Data("{\"ok\":true}".utf8)
        let body = UUHttpBody(contentType: UUContentType.applicationJson, content: payload)

        _ = BodyTestSupport.assertSuccess(
            body.prepareToSend(),
            expectedContentType: UUContentType.applicationJson,
            expectedBody: payload
        )
    }

    func test_prepareToSend_failureWhenEncodeReturnsNil()
    {
        let body = NullEncodingHttpBody()

        BodyTestSupport.assertSerializeFailure(body.prepareToSend())
    }

    func test_prepareToSend_failureWhenEncodeReturnsEmptyData()
    {
        let body = EmptyEncodingHttpBody()

        BodyTestSupport.assertSerializeFailure(body.prepareToSend())
    }

    func test_prepareToSend_propagatesContentEncodingToPreparedHeaders()
    {
        let payload = Data("data".utf8)
        let body = UUHttpBody(
            contentType: UUContentType.textPlain,
            contentEncoding: "gzip",
            content: payload
        )

        _ = BodyTestSupport.assertSuccess(
            body.prepareToSend(),
            expectedContentType: UUContentType.textPlain,
            expectedBody: payload,
            expectedEncoding: "gzip"
        )
    }
}
