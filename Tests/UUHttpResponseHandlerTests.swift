//
//  UUHttpReponseHandlerTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/19/21.
//

import Foundation
import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

class UUHttpReponseHandlerTests: XCTestCase
{
    func test_codableError()
    {
        let parser = UUJsonCodableResponseParser<TestCodable>()
        
        let nsData = "00AA".uuToHexData()
        XCTAssertNotNil(nsData, "Unable to create raw response data")
        
        let data = Data(referencing: nsData!)
        
        let url = URL(string: "https://fake.url")
        XCTAssertNotNil(url)
        
        let request = URLRequest(url: url!)
        let response = HTTPURLResponse(url: url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)
        XCTAssertNotNil(response)
        
        let parsed = parser.parseResponse(data, response!, request)
        XCTAssertNotNil(parsed)
        
        let parsedError = parsed as? Error
        UUAssertError(parsedError, .parseFailure)
    }
    
    func test_codableSuccess()
    {
        let parser = UUJsonCodableResponseParser<TestCodable>()
        
        let obj = TestCodable(fieldOne: "HelloWorld", fieldTwo: 2021)
        let data = obj.toJsonData()
        XCTAssertNotNil(data, "Unable to create response data")
        
        let url = URL(string: "https://fake.url")
        XCTAssertNotNil(url)
        
        let request = URLRequest(url: url!)
        let response = HTTPURLResponse(url: url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)
        XCTAssertNotNil(response)
        
        let parsed = parser.parseResponse(data!, response!, request)
        XCTAssertNotNil(parsed)
        
        let parsedError = parsed as? Error
        XCTAssertNil(parsedError, "Do not expect an error to be returned after success parsing")
        
        let decodedObject = parsed as? TestCodable
        XCTAssertNotNil(decodedObject, "Expect decoded object to be non-nil")
        XCTAssertEqual(decodedObject!, obj, "Expect object to decode and be equal")
    }
}

fileprivate struct TestCodable: Codable, Equatable
{
    var fieldOne: String
    var fieldTwo: Int
    
    static func makeData() -> Data?
    {
        let obj = TestCodable(fieldOne: "HelloWorld", fieldTwo: 2021)
        return obj.toJsonData()
    }
    
    func toJsonData() -> Data?
    {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(self)
        return data
    }
    
    static func == (lhs: TestCodable, rhs: TestCodable) -> Bool
    {
        return
            lhs.fieldOne == rhs.fieldOne &&
            lhs.fieldTwo == rhs.fieldTwo
    }
    
    func hash(into hasher: inout Hasher)
    {
        hasher.combine(fieldOne)
        hasher.combine(fieldTwo)
    }
}

