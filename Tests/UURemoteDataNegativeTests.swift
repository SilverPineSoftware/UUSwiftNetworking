//
//  UURemoteDataNegativeTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 09/01/22.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

class UURemoteDataNegativeTests: XCTestCase
{
    private let testFileName = "uu_remote_data_test.jpg"
    
    override func setUp()
    {
        super.setUp()
    }
    
    open var remoteDataForTest: UURemoteData
    {
        return UURemoteData.shared
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
    
    public func test_recursiveErrorDownload()
    {
        let count = 10000
        let attempts = 10
        
        let exp = uuExpectationForMethod()
        exp.expectedFulfillmentCount = count
        
        let api = remoteDataForTest
        
        let key = "https://dddkj112nrsr4.cloudfront.net/media/jr/dx/jrdxK9/item/BYZkn9/39c1af41c5e94885bdfb9ef90536e59d.jpg"
        
        var startedCount: Int = 0
        var endedCount: Int = 0
        
        for i in 0..<count
        {
            startedCount += 1
            NSLog("Start - \(i), startedCount: \(startedCount), endedCount: \(endedCount)")

            _ = api.data(for: key, remoteLoadCompletion:
            { responseData, responseErr in
                
                endedCount += 1
                NSLog("End - \(i), startedCount: \(startedCount), endedCount: \(endedCount)")
                exp.fulfill()
            })
        }
        
        uuWaitForExpectations()
    }
    
    var remoteFetchCountStarted: Int = 0
    var remoteFetchCountEnded: Int = 0
    
    private func doFetchFromBadUrl(url: String, count: Int, maxAttempts: Int, completion: @escaping ()->())
    {
        if (count >= maxAttempts)
        {
            completion()
            return
        }
        
        let remoteData = remoteDataForTest

        let key = url
        
        remoteFetchCountStarted += 1
        NSLog("Starting fetch, startedCount: \(remoteFetchCountStarted), endedCount: \(remoteFetchCountEnded)")
        
        let data = remoteData.data(for: key, remoteLoadCompletion:
        { remoteDataOpt, remoteErrOpt in
            
            self.remoteFetchCountEnded += 1
            NSLog("Ending fetch, startedCount: \(self.remoteFetchCountStarted), endedCount: \(self.remoteFetchCountEnded)")
            
            XCTAssertNil(remoteDataOpt)
            XCTAssertNotNil(remoteErrOpt)

            self.doFetchFromBadUrl(url: url, count: count + 1, maxAttempts: maxAttempts, completion: completion)
            
        })
                                   
        XCTAssertNil(data)
    }
    
    private func getBadImageUrls(count: Int) -> [String]
    {
        var results: [String] = []
        
        for i in 0..<count
        {
            results.append("http://this.is.a.fake.url/non_existent_\(i).jpg")
        }
        
        return results
    }
    
    
}
