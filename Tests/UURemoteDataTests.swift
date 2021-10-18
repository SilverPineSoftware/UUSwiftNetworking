//
//  UURemoteDataTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/18/21.
//

import XCTest
import UUSwiftCore
@testable import UUSwiftNetworking

class UURemoteDataTests: XCTestCase
{
    static var isFirstTest : Bool = true
    
    private static let testUrl : String = "http://publicdomainarchive.com/?ddownload=47473"

    override func setUp()
    {
        super.setUp()
        
        if (UURemoteDataTests.isFirstTest)
        {
            UUDataCache.shared.clearCache()
            UURemoteDataTests.isFirstTest = false
            UUDataCache.shared.contentExpirationLength = 30 * 24 * 60 * 60
        }
    }
    
    override func tearDown()
    {
        super.tearDown()
    }
    
    func test_0000_fetchNoLocal()
    {
        let key = UURemoteDataTests.testUrl
        
        expectation(forNotification: NSNotification.Name(rawValue: UURemoteData.Notifications.DataDownloaded.rawValue), object: nil)
        { (notification: Notification) -> Bool in
            
            let md = UURemoteData.shared.metaData(for: key)
            XCTAssertNotNil(md)
            
            let data = UURemoteData.shared.data(for: key)
            XCTAssertNotNil(data)
            
            let nKey = notification.uuRemoteDataPath
            XCTAssertNotNil(nKey)
  
            let nErr = notification.uuRemoteDataError
            XCTAssertNil(nErr)
            
            return true
        }
        
        var data = UURemoteData.shared.data(for: key)
        XCTAssertNil(data)
        
        waitForExpectations(timeout: .infinity)
        { (err : Error?) in
            
            if (err != nil)
            {
                XCTFail("failed waiting for expectations, error: \(err!)")
            }
        }
 

        let md = UURemoteData.shared.metaData(for: key)
        data = UURemoteData.shared.data(for: key)
        XCTAssertNotNil(data)
        XCTAssertNotNil(md)
    }
    
    func test_0001_fetchFromBadUrl()
    {
        expectation(forNotification: NSNotification.Name(rawValue: UURemoteData.Notifications.DataDownloadFailed.rawValue), object: nil)
        
        let key = "http://this.is.a.fake.url/non_existent.jpg"
        
        let data = UURemoteData.shared.data(for: key)
        XCTAssertNil(data)
        
        waitForExpectations(timeout: .infinity)
        { (err : Error?) in
            
            if (err != nil)
            {
                XCTFail("failed waiting for expectations, error: \(err!)")
            }
        }
    }
    
    func test_0002_fetchExisting()
    {
        let key = UURemoteDataTests.testUrl
        
        let data = UURemoteData.shared.data(for: key)
        XCTAssertNotNil(data)
    }
    
    func test_0003_downloadMultiple_10()
    {
        let count = 10
        let imageUrls = getImageUrls(count: count)
        XCTAssertTrue(imageUrls.count > 0)
        
        for (index, url) in imageUrls.enumerated()
        {
            let exp = expectation(description: "Iteration_\(index)")
            
            let existing = UURemoteData.shared.data(for: url)
            { result, err in
                XCTAssertNotNil(result)
                XCTAssertNil(err)
                exp.fulfill()
                NSLog("Iteration Complete - \(index)")
            }
            
            XCTAssertNil(existing)
        }
        
        waitForExpectations(timeout: 300, handler: nil)
    }
    
    func test_0004_downloadMultiple_100()
    {
        let count = 100
        let imageUrls = getImageUrls(count: count)
        XCTAssertTrue(imageUrls.count > 0)
        
        for (index, url) in imageUrls.enumerated()
        {
            let exp = expectation(description: "Iteration_\(index)")
            
            let existing = UURemoteData.shared.data(for: url)
            { result, err in
                XCTAssertNotNil(result)
                XCTAssertNil(err)
                exp.fulfill()
                NSLog("Iteration Complete - \(index)")
            }
            
            XCTAssertNil(existing)
        }
        
        waitForExpectations(timeout: 300, handler: nil)
    }
    
    private func getImageUrls(count: Int) -> [String]
    {
        let exp = expectation(description: #function)
        
        var results: [String] = []
        
        ShutterstockApi.fetchImageUrls(count: count)
        { list in
            results.append(contentsOf: list)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        return results
    }
}

fileprivate class ShutterstockApi
{
    class func fetchImageUrls(count: Int, callback: @escaping (([String])->()))
    {
        let url = "https://api.shutterstock.com/v2/images/search"
        
        var args: UUQueryStringArgs = [:]
        args["page"] = "1"
        args["per_page"] = "\(count)"
        args["query"] = "forest"
        
        let req = UUHttpRequest(url: url, method: .get, queryArguments: args)
        
        let username = "d4a89-1400b-04251-4faee-f7a23-12271:61764-d9c3c-8a832-a7bdf-098e4-0b382"
        let usernameData = username.data(using: .utf8)
        let usernameEncoded = usernameData!.base64EncodedString(options: Data.Base64EncodingOptions.init(rawValue: 0))
        req.headerFields["Authorization"] = "Basic \(usernameEncoded)"
        
        _ = UUHttpSession.executeRequest(req)
        { (response: UUHttpResponse) in
        
            var results: [String] = []
            
            if (response.httpError == nil)
            {
                if let parsed = response.parsedResponse as? [AnyHashable:Any],
                   let data = parsed.uuSafeGetDictionaryArray("data")
                {
                    for item in data
                    {
                        if let assets = item.uuSafeGetDictionary("assets")
                        {
                            //small_thumb
                            //large_thumb
                            //huge_thumb
                            //preview
                            //preview_1000
                            //preview_1500
                            
                            let key = "preview_1500"
                            if let d = assets.uuSafeGetDictionary(key),
                               let url = d.uuSafeGetString("url")
                            {
                                if (!results.contains(url))
                                {
                                    results.append(url)
                                }
                            }
                        }
                    }
                }
            }
            
            callback(results)
        }
    }
}
