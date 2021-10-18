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
    private static let testUrl : String = "http://publicdomainarchive.com/?ddownload=47473"

    override func setUp()
    {
        super.setUp()
        
        UUDataCache.shared.clearCache()
        UURemoteData.shared.maxActiveRequests = 50
        UUDataCache.shared.contentExpirationLength = 30 * 24 * 60 * 60
    }
    
    override func tearDown()
    {
        super.tearDown()
    }
    
    func test_fetchNoLocal()
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
    
    func test_fetchFromBadUrl()
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
    
    func test_fetchExisting()
    {
        let key = UURemoteDataTests.testUrl
        
        let exp = expectation(description: #function)
   
        let existing = UURemoteData.shared.data(for: key)
        { result, err in
            exp.fulfill()
        }
        
        XCTAssertNil(existing)
        
        waitForExpectations(timeout: 60, handler: nil)
        
        
        let data = UURemoteData.shared.data(for: key)
        XCTAssertNotNil(data)
    }
    
    func test_downloadMultiple_largeFiles_noDuplicates_10()
    {
        do_concurrentDownloadTest(count: 10, large: true, includeDuplicates: false)
    }
    
    func test_downloadMultiple_largeFiles_noDuplicates_100()
    {
        do_concurrentDownloadTest(count: 100, large: true, includeDuplicates: false)
    }
    
    func test_downloadMultiple_largeFiles_noDuplicates_1000()
    {
        do_concurrentDownloadTest(count: 1000, large: true, includeDuplicates: false)
    }
    
    func test_downloadMultiple_smallFiles_noDuplicates_10()
    {
        do_concurrentDownloadTest(count: 10, large: false, includeDuplicates: false)
    }
    
    func test_downloadMultiple_smallFiles_noDuplicates_100()
    {
        do_concurrentDownloadTest(count: 100, large: false, includeDuplicates: false)
    }
    
    func test_downloadMultiple_smallFiles_noDuplicates_1000()
    {
        do_concurrentDownloadTest(count: 1000, large: false, includeDuplicates: false)
    }
    
    private func do_concurrentDownloadTest(count: Int, large: Bool, includeDuplicates: Bool)
    {
        let imageUrls = getImageUrls(count: count, large: large)
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
    
    private func getImageUrls(count: Int, large: Bool) -> [String]
    {
        let exp = expectation(description: #function)
        
        var results: [String] = []
        
        ShutterstockApi.fetchImageUrls(count: count, large: large)
        { list in
            results.append(contentsOf: list)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        let truncated = Array(results.prefix(count))
        XCTAssertEqual(truncated.count, count)
        return truncated
    }
}

fileprivate class ShutterstockApi
{
    private static let maxPerPage = 500
    
    class func fetchImageUrls(count: Int, large: Bool, callback: @escaping (([String])->()))
    {
        fetchAssets(workingResults: [], page: 1, count: count, query: "forest", assetKey: large ? "preview_1500" : "small_thumb", callback: callback)
    }
    
    private class func fetchAssets(workingResults: [String], page: Int, count: Int, query: String, assetKey: String, callback: @escaping (([String])->()))
    {
        if (workingResults.count >= count)
        {
            callback(workingResults)
            return
        }
        
        fetchAssetPage(page: page, perPage: min(count, maxPerPage), query: query, assetKey: assetKey)
        { pageResult in
            
            var tmp = workingResults
            tmp.append(contentsOf: pageResult)
            fetchAssets(workingResults: tmp, page: page + 1, count: count, query: query, assetKey: assetKey, callback: callback)
        }
    }
    
    private class func fetchAssetPage(page: Int, perPage: Int, query: String, assetKey: String, callback: @escaping (([String])->()))
    {
        let url = "https://api.shutterstock.com/v2/images/search"
        
        var args: UUQueryStringArgs = [:]
        args["page"] = "\(page)"
        args["per_page"] = "\(perPage)" // 500 is the max allowed
        args["query"] = query
        
        let req = UUHttpRequest(url: url, method: .get, queryArguments: args)
        
        let username = "d4a89-1400b-04251-4faee-f7a23-12271:61764-d9c3c-8a832-a7bdf-098e4-0b382"
        let usernameData = username.data(using: .utf8)
        let usernameEncoded = usernameData!.base64EncodedString(options: Data.Base64EncodingOptions.init(rawValue: 0))
        req.headerFields["Authorization"] = "Basic \(usernameEncoded)"
        
        NSLog("Fetching page \(page)")
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
                            
                            if let d = assets.uuSafeGetDictionary(assetKey),
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
