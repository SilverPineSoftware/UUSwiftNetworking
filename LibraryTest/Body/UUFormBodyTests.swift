//
//  UUFormBodyTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/19/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUFormBodyTests: XCTestCase
{
    // MARK: - contentType

    func test_contentType_includesBoundaryInContentType()
    {
        let body = UUFormBody(formBoundary: BodyTestSupport.testBoundary)

        XCTAssertEqual(
            "multipart/form-data; boundary=\(BodyTestSupport.testBoundary)",
            body.contentType
        )
    }

    func test_contentType_usesDefaultBoundaryWhenNotSpecified()
    {
        let body = UUFormBody()

        XCTAssertTrue(body.contentType.contains(UUFormBody.defaultFormBoundary))
    }

    // MARK: - encode

    func test_encode_encodesSingleTextField()
    {
        let body = UUFormBody(formBoundary: BodyTestSupport.testBoundary)
        body.add(field: "username", value: "alice")

        let encoded = String(data: body.encode()!, encoding: .utf8)!

        XCTAssertTrue(encoded.contains("--\(BodyTestSupport.testBoundary)"))
        XCTAssertTrue(encoded.contains("Content-Disposition: form-data; name=\"username\""))
        XCTAssertTrue(encoded.contains("Content-Type: \(UUContentType.textPlain)"))
        XCTAssertTrue(encoded.contains("alice"))
        XCTAssertTrue(encoded.contains("--\(BodyTestSupport.testBoundary)--"))
    }

    func test_encode_encodesMultipleTextFields()
    {
        let body = UUFormBody(formBoundary: BodyTestSupport.testBoundary)
        body.add(field: "fieldOne", value: "first")
        body.add(field: "fieldTwo", value: "second")

        let encoded = String(data: body.encode()!, encoding: .utf8)!

        XCTAssertTrue(encoded.contains("name=\"fieldOne\""))
        XCTAssertTrue(encoded.contains("first"))
        XCTAssertTrue(encoded.contains("name=\"fieldTwo\""))
        XCTAssertTrue(encoded.contains("second"))
    }

    func test_encode_omitsPartContentTypeWhenNull()
    {
        let body = UUFormBody(formBoundary: BodyTestSupport.testBoundary)
        body.add(field: "plain", value: "value", contentType: nil)

        let encoded = String(data: body.encode()!, encoding: .utf8)!

        XCTAssertTrue(encoded.contains("name=\"plain\""))
        XCTAssertTrue(encoded.contains("value"))
        XCTAssertFalse(encoded.contains("Content-Type: \(UUContentType.textPlain)"))
    }

    func test_encode_encodesFilePartWithFilenameAndContentType()
    {
        let fileBytes = Data([0x01, 0x02, 0x03])
        let body = UUFormBody(formBoundary: BodyTestSupport.testBoundary)
        body.addFile(
            fieldName: "upload",
            fileName: "photo.png",
            contentType: UUContentType.imagePng,
            fileData: fileBytes
        )

        let encoded = body.encode()!
        let encodedText = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(encodedText.contains("name=\"upload\""))
        XCTAssertTrue(encodedText.contains("filename=\"photo.png\""))
        XCTAssertTrue(encodedText.contains("Content-Type: \(UUContentType.imagePng)"))
        XCTAssertNotNil(encoded.range(of: fileBytes))
    }

    func test_encode_emptyFormStillProducesClosingBoundary()
    {
        let body = UUFormBody(formBoundary: BodyTestSupport.testBoundary)

        let encoded = String(data: body.encode()!, encoding: .utf8)!

        XCTAssertEqual("\r\n--\(BodyTestSupport.testBoundary)--\r\n", encoded)
    }

    // MARK: - prepareToSend

    func test_prepareToSend_successWhenFieldsArePresent()
    {
        let body = UUFormBody(formBoundary: BodyTestSupport.testBoundary)
        body.add(field: "token", value: "abc123")

        let result = body.prepareToSend()
        guard case .success(let (payload, _)) = result else
        {
            XCTFail("Expected prepareToSend to succeed")
            return
        }

        _ = BodyTestSupport.assertSuccess(
            result,
            expectedContentType: body.contentType,
            expectedBody: payload
        )
    }
}
