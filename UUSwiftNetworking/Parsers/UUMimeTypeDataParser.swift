//
//  UUMimeTypeDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUMimeTypeDataParser"

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
