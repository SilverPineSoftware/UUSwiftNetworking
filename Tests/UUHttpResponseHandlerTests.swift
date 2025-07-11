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
        let parser = UUJsonCodableDataParser<TestCodable>()
        
        let data = "00AA".uuToHexData()
        XCTAssertNotNil(data, "Unable to create raw response data")
        
        //let data = Data(referencing: nsData!)
        
        let url = URL(string: "https://fake.url")
        XCTAssertNotNil(url)
        
        let request = URLRequest(url: url!)
        let response = HTTPURLResponse(url: url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)
        XCTAssertNotNil(response)
        
        let exp = uuExpectationForMethod()
        parser.parse(data: data!, response: response!, request: request)
        { parsedResult in
        
            XCTAssertNotNil(parsedResult)
            
            let parsedError = parsedResult as? Error
            UUAssertError(parsedError, .parseFailure)
            exp.fulfill()
        }
            
        uuWaitForExpectations()
    }
    
    func test_codableSuccess()
    {
        let parser = UUJsonCodableDataParser<TestCodable>()
        
        let obj = TestCodable(fieldOne: "HelloWorld", fieldTwo: 2021)
        let data = obj.toJsonData()
        XCTAssertNotNil(data, "Unable to create response data")
        
        let url = URL(string: "https://fake.url")
        XCTAssertNotNil(url)
        
        let request = URLRequest(url: url!)
        let response = HTTPURLResponse(url: url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)
        XCTAssertNotNil(response)
        
        let exp = uuExpectationForMethod()
        parser.parse(data: data!, response: response!, request: request)
        { parsedResult in
        
            XCTAssertNotNil(parsedResult)
            
            let parsedError = parsedResult as? Error
            XCTAssertNil(parsedError, "Do not expect an error to be returned after success parsing")
            
            let decodedObject = parsedResult as? TestCodable
            XCTAssertNotNil(decodedObject, "Expect decoded object to be non-nil")
            XCTAssertEqual(decodedObject!, obj, "Expect object to decode and be equal")
            
            exp.fulfill()
        }
            
        uuWaitForExpectations()
    }
    
    
    func test_codableSuccess_withJsonParser()
    {
        let parserExp = uuExpectationForMethod(tag: "parser configure")
        let parser = UUJsonCodableDataParser<TestCodable>()
        parser.configureJsonDecoder =
        { decoder in
        
            NSLog("Json configure called")
            parserExp.fulfill()
        }
        
        let obj = TestCodable(fieldOne: "HelloWorld", fieldTwo: 2021)
        let data = obj.toJsonData()
        XCTAssertNotNil(data, "Unable to create response data")
        
        let url = URL(string: "https://fake.url")
        XCTAssertNotNil(url)
        
        let request = URLRequest(url: url!)
        let response = HTTPURLResponse(url: url!, statusCode: 200, httpVersion: "2.0", headerFields: nil)
        XCTAssertNotNil(response)
        
        let exp = uuExpectationForMethod()
        parser.parse(data: data!, response: response!, request: request)
        { parsedResult in
        
            XCTAssertNotNil(parsedResult)
            
            let parsedError = parsedResult as? Error
            XCTAssertNil(parsedError, "Do not expect an error to be returned after success parsing")
            
            let decodedObject = parsedResult as? TestCodable
            XCTAssertNotNil(decodedObject, "Expect decoded object to be non-nil")
            XCTAssertEqual(decodedObject!, obj, "Expect object to decode and be equal")
            
            exp.fulfill()
        }
            
        wait(for: [parserExp, exp], timeout: 5)
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

