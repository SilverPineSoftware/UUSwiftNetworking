//
//  UUJsonCodableResponseHandler.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUJsonCodableResponseHandler"

open class UUJsonCodableResponseHandler<SuccessType: Codable, ErrorType: Codable>: UUBaseResponseHandler
{
    public required init()
    {
        super.init()
    }
    
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
