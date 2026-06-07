//
//  UUJsonBodyTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/19/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUJsonBodyTests: XCTestCase
{
    // MARK: - contentType

    func test_contentType_usesApplicationJson()
    {
        let body = UUJsonBody(BodyTestModel(id: "x", count: 1))

        XCTAssertEqual(UUContentType.applicationJson, body.contentType)
    }

    // MARK: - encode

    func test_encode_serializesObjectToUtf8Json()
    {
        let model = BodyTestModel(id: "item-42", count: 99)
        let body = UUJsonBody(model)

        let encoded = body.encode()!
        let decoded = try! JSONDecoder().decode(BodyTestModel.self, from: encoded)

        XCTAssertEqual(model, decoded)
    }

    func test_encode_returnsNilWhenSerializationFails()
    {
        let body = UUJsonBody(BodyTestUnencodableModel(value: "nope"))

        XCTAssertNil(body.encode())
    }

    func test_encode_respectsCustomJsonEncoder()
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let body = UUJsonBody(BodyTestModel(id: "a", count: 1))
        body.jsonEncoder = encoder

        let jsonText = String(data: body.encode()!, encoding: .utf8)!

        XCTAssertEqual("{\"count\":1,\"id\":\"a\"}", jsonText)
    }

    // MARK: - prepareToSend

    func test_prepareToSend_successReturnsJsonPayloadAndHeaders()
    {
        let model = BodyTestModel(id: "send", count: 3)
        let body = UUJsonBody(model)

        let result = body.prepareToSend()
        let (payload, _) = BodyTestSupport.assertSuccess(
            result,
            expectedContentType: UUContentType.applicationJson,
            validateBody: { data in
                let decoded = try JSONDecoder().decode(BodyTestModel.self, from: data)
                XCTAssertEqual(model, decoded)
            }
        )

        XCTAssertFalse(payload.isEmpty)
    }

    func test_prepareToSend_failureWhenModelCannotBeSerialized()
    {
        let body = UUJsonBody(BodyTestUnencodableModel(value: "bad"))

        BodyTestSupport.assertSerializeFailure(body.prepareToSend())
    }
}
