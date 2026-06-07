//
//  BodyTestSupport.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/19/26.
//

import Foundation
import XCTest
@testable import UUSwiftNetworking

enum BodyTestSupport
{
    static let testBoundary = "TestBoundary123"

    static func assertSerializeFailure(_ result: Result<(Data, UUHttpHeaders), Error>, file: StaticString = #filePath, line: UInt = #line)
    {
        switch result
        {
        case .success:
            XCTFail("Expected serialize failure", file: file, line: line)
        case .failure(let error):
            XCTAssertEqual(error.uuHttpErrorCode, .serializeFailure, file: file, line: line)
        }
    }

    static func assertSuccess(
        _ result: Result<(Data, UUHttpHeaders), Error>,
        expectedContentType: String,
        expectedBody: Data,
        expectedEncoding: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (Data, UUHttpHeaders)
    {
        assertSuccess(
            result,
            expectedContentType: expectedContentType,
            expectedEncoding: expectedEncoding,
            validateBody: { XCTAssertEqual(expectedBody, $0, file: file, line: line) },
            file: file,
            line: line
        )
    }

    static func assertSuccess(
        _ result: Result<(Data, UUHttpHeaders), Error>,
        expectedContentType: String,
        expectedEncoding: String? = nil,
        validateBody: (Data) throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (Data, UUHttpHeaders)
    {
        switch result
        {
        case .failure(let error):
            XCTFail("Expected success, got \(error)", file: file, line: line)
            return (Data(), [:])
        case .success(let pair):
            do
            {
                try validateBody(pair.0)
            }
            catch
            {
                XCTFail("Body validation failed: \(error)", file: file, line: line)
            }
            XCTAssertEqual(expectedContentType, pair.1[UUHttpHeader.contentType] as? String, file: file, line: line)
            XCTAssertEqual(pair.0.count, pair.1[UUHttpHeader.contentLength] as? Int, file: file, line: line)
            if let expectedEncoding
            {
                XCTAssertEqual(expectedEncoding, pair.1[UUHttpHeader.contentEncoding] as? String, file: file, line: line)
            }
            else
            {
                XCTAssertNil(pair.1[UUHttpHeader.contentEncoding], file: file, line: line)
            }
            return pair
        }
    }
}

struct BodyTestModel: Codable, Equatable
{
    var id: String = ""
    var count: Int = 0
}

/// Always fails JSON encoding — used to force ``UUJsonBody`` encode failure.
struct BodyTestUnencodableModel: Codable
{
    let value: String

    func encode(to encoder: Encoder) throws
    {
        throw EncodingError.invalidValue(
            value,
            EncodingError.Context(codingPath: [], debugDescription: "forced encoding failure")
        )
    }
}

final class NullEncodingHttpBody: UUHttpBody
{
    init(contentType: String = UUContentType.textPlain)
    {
        super.init(contentType: contentType, contentEncoding: nil, content: nil)
    }

    override func encode() -> Data?
    {
        return nil
    }
}

final class EmptyEncodingHttpBody: UUHttpBody
{
    init(contentType: String = UUContentType.textPlain)
    {
        super.init(contentType: contentType, contentEncoding: nil, content: nil)
    }

    override func encode() -> Data?
    {
        return Data()
    }
}
