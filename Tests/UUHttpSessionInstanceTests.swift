//
//  UUHttpSessionInstanceTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/22/21.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

class UUHttpSessionInstanceTests: XCTestCase
{
    private var uuHttpSessionForTest: UUHttpSession
    {
        return UUHttpSession()
    }
    
    func test_getCodableObject()
    {
        let session = uuHttpSessionForTest
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
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
        
        _ = session.executeCodableRequest(request)
        { (response: SimpleObject?, err: Error?) in
            
            XCTAssertNotNil(response)
            XCTAssertNil(err)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_getCodableArray()
    {
        let session = uuHttpSessionForTest
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
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
        
        _ = session.executeCodableRequest(request)
        { (response: [SimpleObject]?, err: Error?) in
            
            XCTAssertNotNil(response)
            XCTAssertNil(err)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
    
    func test_formPost()
    {
        let session = uuHttpSessionForTest
        
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.formPostUrl
        
        let request = UUHttpRequest(url: url, method: .post)
        
        let form = UUHttpForm()
        form.add(field: "FileType", value: "Image", contentType: "text/plain")
        
        let fileName = "uploadFileTest.jpg"
        
        if let filePath = cfg.uploadFilePath,
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
        
        _ = session.executeRequest(request)
        { response in
            
            XCTAssertNil(response.httpError)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
        
        verifyUploadedFile(fileName)
    }
    
    private func verifyUploadedFile(_ fileName: String)
    {
        let session = uuHttpSessionForTest
        
        let exp = uuExpectationForMethod()
        let cfg = UULoadNetworkingTestConfig()
        let url = "\(cfg.downloadFileUrl)?uu_file=\(fileName)"
        
        let request = UUHttpRequest(url: url, method: .get)
        
        _ = session.executeRequest(request)
        { response in
            
            XCTAssertNotNil(response.parsedResponse)
            XCTAssertNil(response.httpError)
            
            let img = response.parsedResponse as? UIImage
            XCTAssertNotNil(img)
            
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
}


fileprivate class SimpleObject: Codable
{
    var fieldOne: String
    var fieldTwo: Int
}

