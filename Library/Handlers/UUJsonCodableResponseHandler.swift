//
//  UUJsonCodableResponseHandler.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUJsonCodableResponseHandler"

/// Response handler that decodes JSON success and error bodies into distinct `Codable` types.
///
/// Wires ``UUJsonCodableDataParser`` for both ``successParser`` and ``errorParser``, sharing
/// ``jsonDecoder`` when the parser instances are created.
open class UUJsonCodableResponseHandler<SuccessType: Codable, ErrorType: Codable>: UUBaseResponseHandler
{
    public required init()
    {
        super.init()
    }
    
    /// Decoder applied to both success and error JSON parsers.
    public var jsonDecoder: JSONDecoder = JSONDecoder()
    
    open override var successParser: UUHttpDataParser
    {
        let parser = UUJsonCodableDataParser<SuccessType>()
        parser.jsonDecoder = self.jsonDecoder
        return parser
    }
    
    open override var errorParser: UUHttpDataParser
    {
        let parser = UUJsonCodableDataParser<ErrorType>()
        parser.jsonDecoder = self.jsonDecoder
        return parser
    }
}
