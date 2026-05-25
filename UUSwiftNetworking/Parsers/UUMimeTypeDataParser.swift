//
//  UUMimeTypeDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUMimeTypeDataParser"

/// Composite parser that delegates to a MIME-specific ``UUHttpDataParser`` based on `HTTPURLResponse.mimeType`.
///
/// Default registrations (see ``init()``):
/// - JSON → ``UUJsonDataParser``
/// - HTML / plain text → ``UUTextDataParser``
/// - Octet-stream → ``UUBinaryDataParser``
/// - PNG / JPEG → ``UUImageDataParser``
/// - Form URL encoded → ``UUFormEncodedDataParser``
///
/// Register additional types with ``registerResponseHandler(_:_:)``.
/// Used as the default success and error parser on ``UUBaseResponseHandler``.
open class UUMimeTypeDataParser: UUHttpDataParser
{
    private var parsers: [String:UUHttpDataParser] = [:]
    
    public required init()
    {
        registerResponseHandler([UUContentType.applicationJson, UUContentType.textJson], UUJsonDataParser())
        registerResponseHandler([UUContentType.textHtml, UUContentType.textPlain], UUTextDataParser())
        registerResponseHandler([UUContentType.binary], UUBinaryDataParser())
        registerResponseHandler([UUContentType.imagePng, UUContentType.imageJpeg], UUImageDataParser())
        registerResponseHandler([UUContentType.formEncoded], UUFormEncodedDataParser())
    }
    
    /// Associates one or more MIME type strings with a parser instance.
    public func registerResponseHandler(_ mimeTypes: [String], _ parser: UUHttpDataParser)
    {
        for mimeType in mimeTypes
        {
            parsers[mimeType] = parser
        }
    }
    
    open func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
    {
        guard let mimeType = response.mimeType else
        {
            return nil
        }
        
        guard let parser = parsers[mimeType] else
        {
            return nil
        }
        
        return await parser.parse(data: data, response: response, request: request)
    }
}
