//
//  UURemoteDataTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/18/21.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

class UURemoteDataTests: XCTestCase
{
    private let testFileName = "uu_remote_data_test.jpg"
    
    override func setUp()
    {
        super.setUp()
        
        remoteDataForTest.dataCache.clearCache()
        remoteDataForTest.maxActiveRequests = 50
        remoteDataForTest.dataCache.contentExpirationLength = 30 * 24 * 60 * 60
    }
    
    open var remoteDataForTest: UURemoteData
    {
        let api = UURemoteData.shared
        api.networkTimeout = 300.0
        return api
    }
    
    open var concurrentDownloadCount: Int
    {
        return 10
    }
    
    private var testUrl: String
    {
        let cfg = UULoadNetworkingTestConfig()
        return "\(cfg.downloadFileUrl)?uu_file=\(testFileName)"
    }
    
    override func tearDown()
    {
        super.tearDown()
    }
    
    func test_fetchNoLocal()
    {
        let key = testUrl
        
        let remoteData = remoteDataForTest
        
        expectation(forNotification: NSNotification.Name(rawValue: UURemoteData.Notifications.DataDownloaded.rawValue), object: nil)
        { (notification: Notification) -> Bool in
            
            let md = remoteData.metaData(for: key)
            XCTAssertNotNil(md)
            
            let data = remoteData.data(for: key)
            XCTAssertNotNil(data)
            
            let nKey = notification.uuRemoteDataPath
            XCTAssertNotNil(nKey)
  
            let nErr = notification.uuRemoteDataError
            XCTAssertNil(nErr)
            
            return true
        }
        
        var data = remoteData.data(for: key)
        XCTAssertNil(data)
        
        waitForExpectations(timeout: .infinity)
        { (err : Error?) in
            
            if (err != nil)
            {
                XCTFail("failed waiting for expectations, error: \(err!)")
            }
        }
 

        let md = remoteData.metaData(for: key)
        data = remoteData.data(for: key)
        XCTAssertNotNil(data)
        XCTAssertNotNil(md)
    }
    
    func test_fetchFromBadUrl()
    {
        let remoteData = remoteDataForTest
        
        expectation(forNotification: NSNotification.Name(rawValue: UURemoteData.Notifications.DataDownloadFailed.rawValue), object: nil)
        
        let key = "http://this.is.a.fake.url/non_existent.jpg"
        
        let data = remoteData.data(for: key)
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
        uploadTestPhoto()
        
        let remoteData = remoteDataForTest
        let key = testUrl
        
        let exp = expectation(description: #function)
   
        let existing = remoteData.data(for: key)
        { result, err in
            exp.fulfill()
        }
        
        XCTAssertNil(existing)
        
        waitForExpectations(timeout: 60, handler: nil)
        
        let data = remoteData.data(for: key)
        XCTAssertNotNil(data)
    }
    
    func test_downloadMultiple_largeFiles_noDuplicates()
    {
        do_concurrentDownloadTest(count: concurrentDownloadCount, large: true, includeDuplicates: false)
    }
    
    func test_downloadMultiple_smallFiles_noDuplicates()
    {
        do_concurrentDownloadTest(count: concurrentDownloadCount, large: false, includeDuplicates: false)
    }
    
    func test_downloadMultiple_largeFiles_withDuplicates()
    {
        do_concurrentDownloadTest(count: concurrentDownloadCount, large: true, includeDuplicates: true)
    }
    
    func test_downloadMultiple_smallFiles_withDuplicates()
    {
        do_concurrentDownloadTest(count: concurrentDownloadCount, large: false, includeDuplicates: true)
    }
    
    private func do_concurrentDownloadTest(count: Int, large: Bool, includeDuplicates: Bool)
    {
        let remoteData = remoteDataForTest
        
        let imageUrls = getImageUrls(count: count, large: large)
        XCTAssertTrue(imageUrls.count > 0)
        
        for (index, url) in imageUrls.enumerated()
        {
            UUTestLog("Fetching Data for URL: \(url)")
            
            let exp = expectation(description: "Iteration_\(index)")
            
            let existing = remoteData.data(for: url)
            { result, err in
                
                UUTestLog("HTTP Code: \(String(describing: err?.uuHttpStatusCode))")
                
                // Special case - sometimes, randomly shutterstock will give a URL that doesn't exist, so
                // we just ignore that condition and let the test proceed
                if (err?.uuHttpStatusCode != 404)
                {
                    XCTAssertNotNil(result)
                    XCTAssertNil(err)
                }
                
                exp.fulfill()
                UUTestLog("Iteration Complete - \(index)")
            }
            
            if (includeDuplicates)
            {
                usleep(50)
                
                let expInner = expectation(description: "Iteration_\(index)_inner")
                let innerResult = remoteData.data(for: url)
                { result, err in
                    
                    // Special case - sometimes, randomly shutterstock will give a URL that doesn't exist, so
                    // we just ignore that condition and let the test proceed
                    if (err?.uuHttpStatusCode != 404)
                    {
                        XCTAssertNotNil(result)
                        XCTAssertNil(err)
                    }
                    
                    expInner.fulfill()
                    UUTestLog("Iteration Complete - \(index) - Inner")
                }
                
                if (innerResult != nil)
                {
                    expInner.fulfill()
                }
            }
            else
            {
                XCTAssertNil(existing)
            }
            
            // The value may or may not be nil, so there is nothing to assert
        }
        
        waitForExpectations(timeout: 900, handler: nil)
    }
    
    private func getImageUrls(count: Int, large: Bool) -> [String]
    {
        let exp = expectation(description: #function)
        
        var results: [String] = []
        
        UUShutterstockApi.fetchImageUrls(count: count, large: large)
        { list in
            results.append(contentsOf: list)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 60, handler: nil)
        
        let truncated = Array(results.prefix(count))
        XCTAssertEqual(truncated.count, count)
        return truncated
    }
    
    
    private func uploadTestPhoto()
    {
        let exp = uuExpectationForMethod()
        
        let cfg = UULoadNetworkingTestConfig()
        let url = cfg.formPostUrl
        
        let request = UUHttpRequest(url: url, method: .post)
        
        let form = UUHttpForm()
        form.add(field: "FileType", value: "Image", contentType: "text/plain")
        
        let fileName = testFileName
        
        if let filePath = cfg.uploadFilePath,
           let data = try? Data(contentsOf: filePath)
        {
            form.addFile(fieldName: "uu_file", fileName: fileName, contentType: "image/jpeg", fileData: data)
        }
        
        request.form = form
        
        remoteDataForTest.remoteApi.executeOneRequest(request)
        { response in
            
            XCTAssertNil(response.httpError)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
        
        verifyUploadedFile(fileName)
    }
    
    private func verifyUploadedFile(_ fileName: String)
    {
        let exp = uuExpectationForMethod()
        let cfg = UULoadNetworkingTestConfig()
        let url = "\(cfg.downloadFileUrl)?uu_file=\(fileName)"
        
        let request = UUHttpRequest(url: url, method: .get)
        
        remoteDataForTest.remoteApi.executeOneRequest(request)
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
