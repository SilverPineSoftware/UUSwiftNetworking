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
        
        let cfg = try loadTestConfig()
        let url = cfg.echoJsonUrl
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "SomeValue"
        queryArgs["fieldTwo"] = 1234
        
        var headers = UUHttpHeaders()
        headers["UU-Return-Object-Count"] = 1
        
        let request = UUCodableHttpRequest<SimpleObject, UUEmptyResponse>(
            url: url,
            method: .get,
            queryArguments: queryArgs,
            headers: headers)
        
        let result = await session.executeCodableRequest(request)
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
        
        let cfg = try loadTestConfig()
        let url = cfg.echoJsonUrl
        
        var queryArgs = UUQueryStringArgs()
        queryArgs["fieldOne"] = "SomeValue"
        queryArgs["fieldTwo"] = 1234
        
        var headers = UUHttpHeaders()
        headers["UU-Return-Object-Count"] = 3
        
        let request = UUCodableHttpRequest<[SimpleObject], UUEmptyResponse>(
            url: url,
            method: .get,
            queryArguments: queryArgs,
            headers: headers)
        
        let result = await session.executeCodableRequest(request)
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
        
        let cfg = try loadTestConfig()
        let url = cfg.formPostUrl
        
        let request = UUHttpRequest(url: url, method: .post)
        
        let form = UUHttpForm()
        form.add(field: "FileType", value: "Image", contentType: "text/plain")
        
        let fileName = "uploadFileTest.jpg"
        
        if let filePath = cfg.uploadImageFilePath,
           let data = try? Data(contentsOf: filePath)
        {
            form.addFile(fieldName: "uu_file", fileName: fileName, contentType: "image/jpeg", fileData: data)
        }
        
        request.form = form
        
        if let data = form.formData(),
           let str = String(data: data, encoding: .ascii)?.uuSubString(0, 1000)
        {
            UUTestLog("Form:\n\n\(str))\n\n")
        }
        
        let response = await session.executeRequest(request)
        XCTAssertNil(response.httpError)
        
        try await verifyUploadedFile(fileName)
    }
    
    private func verifyUploadedFile(_ fileName: String) async throws
    {
        let session = uuHttpSessionForTest
        
        let cfg = try loadTestConfig()
        let url = "\(cfg.downloadFileUrl)?uu_file=\(fileName)"
        
        let request = UUHttpRequest(url: url, method: .get)
        
        let response = await session.executeRequest(request)
        
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

