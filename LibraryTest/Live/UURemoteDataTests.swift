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

class UURemoteDataTests: BaseOnlineTest
{
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
        let cfg = try? loadTestConfig()
        return cfg?.fullDownloadFileUrl ?? ""
    }
    
    override func tearDown()
    {
        super.tearDown()
    }
    
    func test_fetchNoLocal()
    {
        let key = testUrl
        
        let remoteData = remoteDataForTest
        
        expectation(
            forNotification: UURemoteData.Notifications.DataDownloaded,
            object: nil
        ) { notification in
            notification.uuRemoteDataPath == key
        }
        
        var data = remoteData.data(for: key)
        XCTAssertNil(data)
        
        uuWaitForExpectations()

        let md = remoteData.metaData(for: key)
        data = remoteData.data(for: key)
        XCTAssertNotNil(data)
        XCTAssertNotNil(md)
    }
    
    /*
    func test_fetchNoLocal_async() async throws
    {
        let key = testUrl
        let remoteData = remoteDataForTest
        
        XCTAssertNil(remoteData.cachedData(for: key))
        
        let data = try await remoteData.data(for: key)
        
        XCTAssertNotNil(data)
        XCTAssertNotNil(remoteData.cachedData(for: key))
        XCTAssertNotNil(remoteData.metaData(for: key))
    }*/
    
    func test_fetchFromBadUrl()
    {
        let remoteData = remoteDataForTest
        
        expectation(forNotification: NSNotification.Name(rawValue: UURemoteData.Notifications.DataDownloadFailed.rawValue), object: nil) { _ in
            true
        }
        
        let key = "http://this.is.a.fake.url/non_existent.jpg"
        
        let data = remoteData.data(for: key)
        XCTAssertNil(data)
        
        uuWaitForExpectations()
        
        let dataAfterNotification = remoteData.data(for: key)
        XCTAssertNil(dataAfterNotification)
    }
    
    func test_fetchExisting() throws
    {
        try uploadTestPhoto()
        
        let remoteData = remoteDataForTest
        let key = testUrl
        
        let exp = expectation(description: #function)
   
        let existing = remoteData.data(for: key)
        { result, err in
            exp.fulfill()
        }
        
        XCTAssertNil(existing)
        
        uuWaitForExpectations()
        
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
        
        let expLock = NSLock()
        var startedExpectations = 0
        
        for (index, url) in imageUrls.enumerated()
        {
            UUTestLog("Fetching Data for URL: \(url)")
            
            let exp = expectation(description: "Iteration_\(index)")
            
            expLock.withLock {
                startedExpectations = startedExpectations + 1
                UUTestLog("startedExpectations: \(startedExpectations)")
            }
            
            let existing = remoteData.data(for: url)
            { [url] result, err in
                
                UUTestLog("HTTP Code: \(String(describing: err?.uuHttpStatusCode))")
                
                
                if let httpCode = err?.uuHttpStatusCode
                {
                    switch (httpCode)
                    {
                        // Special case - sometimes api will return urls that get a 403.  Just ignore them
                        case 403:
                            UUTestLog("Skipping 403 Forbidden for \(url)")
                        
                        // Special case - sometimes, randomly shutterstock will give a URL that doesn't exist, so
                        // we just ignore that condition and let the test proceed
                        case 404:
                            UUTestLog("Skipping 404 Not Found for \(url)")
                        
                        break
                        
                        default:
                            XCTAssertNotNil(result)
                            XCTAssertNil(err)
                            break
                    }
                }
            
                exp.fulfill()
                UUTestLog("Iteration Complete - \(index)")
                expLock.withLock {
                    startedExpectations = startedExpectations - 1
                    UUTestLog("startedExpectations: \(startedExpectations)")
                }
            }
            
            if (includeDuplicates)
            {
                usleep(50)
                
                let expInner = expectation(description: "Iteration_\(index)_inner")
                
                expLock.withLock {
                    startedExpectations = startedExpectations + 1
                    UUTestLog("startedExpectations: \(startedExpectations)")
                }
                
                let innerResult = remoteData.data(for: url)
                { [url] result, err in
                    
                    if let httpCode = err?.uuHttpStatusCode
                    {
                        switch (httpCode)
                        {
                            // Special case - sometimes api will return urls that get a 403.  Just ignore them
                            case 403:
                                UUTestLog("Skipping 403 Forbidden for \(url)")
                            
                            // Special case - sometimes, randomly shutterstock will give a URL that doesn't exist, so
                            // we just ignore that condition and let the test proceed
                            case 404:
                                UUTestLog("Skipping 404 Not Found for \(url)")
                            
                            break
                            
                            default:
                                XCTAssertNotNil(result)
                                XCTAssertNil(err)
                                break
                        }
                    }
                    
                    expInner.fulfill()
                    UUTestLog("Iteration Complete - \(index) - Inner")
                    expLock.withLock {
                        startedExpectations = startedExpectations - 1
                        UUTestLog("startedExpectations: \(startedExpectations)")
                    }
                }
                
                if (innerResult != nil)
                {
                    expInner.fulfill()
                    UUTestLog("Iteration Complete - \(index) - Inner (already downloaded)")
                    expLock.withLock {
                        startedExpectations = startedExpectations - 1
                        UUTestLog("startedExpectations: \(startedExpectations)")
                    }
                }
            }
            else
            {
                XCTAssertNil(existing)
            }
            
            // The value may or may not be nil, so there is nothing to assert
        }
        
        UUTestLog("Waiting for all expectations to complete")
        uuWaitForExpectations(900)
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
        
        uuWaitForExpectations()
        
        let truncated = Array(results.prefix(count))
        XCTAssertEqual(truncated.count, count)
        return truncated
    }
    
    private func uploadTestPhoto() throws
    {
        let exp = uuExpectationForMethod()
        
        let cfg = try loadTestConfig()
        let url = cfg.formPostUrl
        
        let request = UUHttpRequest(url: url, method: .post)
        
        let form = UUFormBody()
        form.add(field: "FileType", value: "Image", contentType: "text/plain")
        
        let fileName = cfg.uploadImageFileName
        
        if let filePath = cfg.uploadImageFilePath,
           let data = try? Data(contentsOf: filePath)
        {
            form.addFile(fieldName: "uu_file", fileName: fileName, contentType: "image/jpeg", fileData: data)
        }
        
        request.body = form
        
        remoteDataForTest.executeRequest(request)
        { response in
            
            XCTAssertNil(response.httpError)
            exp.fulfill()
        }
        
        uuWaitForExpectations()
        
        try verifyUploadedFile(fileName)
    }
    
    private func verifyUploadedFile(_ fileName: String) throws
    {
        let exp = uuExpectationForMethod()
        let cfg = try loadTestConfig()
        let url = "\(cfg.downloadFileUrl)?uu_file=\(fileName)"
        
        let request = UUHttpRequest(url: url, method: .get)
        
        remoteDataForTest.executeRequest(request)
        { response in
            
            XCTAssertNotNil(response.parsedResponse)
            XCTAssertNil(response.httpError)
            
            #if canImport(UIKit)
            let img = response.parsedResponse as? UIImage
            XCTAssertNotNil(img)
            #elseif canImport(AppKit)
            let img = response.parsedResponse as? NSImage
            XCTAssertNotNil(img)
            #else
            XCTAssertNotNil(response.parsedResponse)
            #endif
            
            exp.fulfill()
        }
        
        uuWaitForExpectations()
    }
}

