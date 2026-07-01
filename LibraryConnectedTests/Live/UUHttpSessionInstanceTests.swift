//
//  UUHttpSessionInstanceTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/22/21.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore
#if canImport(UIKit)
import UIKit
#endif

@testable import UUSwiftNetworking

class UUHttpSessionInstanceTests: BaseOnlineTest
{
    func test_getCodableObject() async throws
    {
        let session = uuHttpSessionForTest
        
        let url = testConfig.echoJsonUrl
        
        var queryArgs = [URLQueryItem]()
        queryArgs.append(URLQueryItem(name: "fieldOne", value: "SomeValue"))
        queryArgs.append(URLQueryItem(name: "fieldTwo", value: "1234"))
        
        var headers = UUHttpHeaders()
        headers["UU-Return-Object-Count"] = 1
        
        let request = UUCodableHttpRequest<SimpleObject, UUEmptyCodable>(
            url: url,
            method: .get,
            queryItems: queryArgs,
            headers: headers)
        
        let result = await session.executeTyped(request)
        switch (result)
        {
            case .success(let response):
                XCTAssertEqual(response.fieldOne, "SomeValue")
                XCTAssertEqual(response.fieldTwo, 1234)
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
    
    func test_getCodableArray() async throws
    {
        let session = uuHttpSessionForTest
        
        let url = testConfig.echoJsonUrl
        
        var queryArgs = [URLQueryItem]()
        queryArgs.append(URLQueryItem(name: "fieldOne", value: "SomeValue"))
        queryArgs.append(URLQueryItem(name: "fieldTwo", value: "1234"))
        
        var headers = UUHttpHeaders()
        headers["UU-Return-Object-Count"] = 3
        
        let request = UUCodableHttpRequest<[SimpleObject], UUEmptyCodable>(
            url: url,
            method: .get,
            queryItems: queryArgs,
            headers: headers)
        
        let result = await session.executeTyped(request)
        switch (result)
        {
            case .success(let response):
                XCTAssertEqual(response.count, 3)
            
            case .failure(let err):
                XCTFail("Unexpected failure: \(err)")
        }
    }
    
    func test_formPost() async throws
    {
        let session = uuHttpSessionForTest
        
        let url = testConfig.formPostUrl
        
        let request = UUHttpRequest(url: url, method: .post)
        
        let form = UUFormBody()
        form.add(field: "FileType", value: "Image", contentType: "text/plain")
        
        let fileName = "uploadFileTest.jpg"
        
        if let filePath = testConfig.uploadImageFilePath,
           let data = try? Data(contentsOf: filePath)
        {
            form.addFile(fieldName: "uu_file", fileName: fileName, contentType: "image/jpeg", fileData: data)
        }
        
        request.body = form
        
        if let data = form.encode(),
           let str = String(data: data, encoding: .ascii)?.uuSubString(0, 1000)
        {
            UUTestLog("Form:\n\n\(str))\n\n")
        }
        
        let response = await session.execute(request)
        XCTAssertNil(response.httpError)
        
        try await verifyUploadedFile(fileName)
    }
    
    private func verifyUploadedFile(_ fileName: String) async throws
    {
        let session = uuHttpSessionForTest
        
        let url = "\(testConfig.downloadFileUrl)?uu_file=\(fileName)"
        
        let request = UUHttpRequest(url: url, method: .get)
        
        let response = await session.execute(request)
        
        XCTAssertNotNil(response.parsedResponse)
        XCTAssertNil(response.httpError)
        
        #if canImport(UIKit)
        let img = response.parsedResponse as? UIImage
        XCTAssertNotNil(img)
        #else
        XCTAssertNotNil(response.parsedResponse)
        #endif
    }
}


fileprivate class SimpleObject: Codable
{
    var fieldOne: String
    var fieldTwo: Int
}

