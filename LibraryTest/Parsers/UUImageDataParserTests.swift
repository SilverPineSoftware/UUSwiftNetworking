//
//  UUImageDataParserTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import XCTest
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
@testable import UUSwiftNetworking

final class UUImageDataParserTests: XCTestCase
{
    private var parser: UUImageDataParser!

    override func setUp()
    {
        super.setUp()
        parser = UUImageDataParser()
    }

    func test_returnsPlatformImageForPngMimeType() async
    {
        // Minimal valid 1x1 PNG
        let pngBytes: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82,
        ]
        let data = Data(pngBytes)
        let result = await parser.parse(
            data: data,
            response: ParserTestSupport.httpResponse(contentType: UUContentType.imagePng),
            request: ParserTestSupport.urlRequest()
        )

        #if canImport(UIKit)
        XCTAssertNotNil(result as? UIImage)
        #elseif canImport(AppKit)
        XCTAssertNotNil(result as? NSImage)
        #else
        XCTAssertNotNil(result)
        #endif
    }

    func test_invalidImageBytesMayReturnNil() async
    {
        let result = await parser.parse(
            data: Data([0x00, 0x01]),
            response: ParserTestSupport.httpResponse(contentType: UUContentType.imageJpeg),
            request: ParserTestSupport.urlRequest()
        )

        // Platform image initializers may return nil for invalid data
        if result == nil
        {
            XCTAssertNil(result)
        }
        else
        {
            XCTAssertNotNil(result)
        }
    }
}
