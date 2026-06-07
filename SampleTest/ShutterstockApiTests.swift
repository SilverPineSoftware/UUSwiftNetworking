//
//  UUSwiftNetworkingSampleTests.swift
//  UUSwiftNetworkingSampleTests
//
//  Created by Ryan DeVore on 6/6/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import XCTest
import UUSwiftTestCore
import UUSwiftCore
import UUSwiftNetworking
@testable import UUSwiftNetworkingSample

final class UUShutterstockApiTests: XCTestCase
{

    override func setUpWithError() throws
    {
        let logger = UULogger.console
        logger.logLevel = .debug
        UULog.setLogger(logger)
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        //try sleep_type_t
        uuTestWait(5)
    }

    func testSearch2() async throws
    {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest
        
        let api = ShutterstockApi()
        
        let result = await api.searchImages2(query: "cat", page: 1, count: 10, large: true)
        
        switch (result)
        {
            case .success(let urls):
                UUTestLog("Got \(urls.count) URLs,\n\n\(urls.joined(separator: "\n"))")
                XCTAssertGreaterThan(urls.count, 0)
            
            case .failure(let error):
                XCTFail("\(error)")
        }
    }
    
    func testSearch() async throws
    {
        /*let api = ShutterstockApi()
        
        let request = ShutterstockSearchImagesRequest()
        
        let result = await api.searchImages(request)
        
        switch (result)
        {
            case .success(let urls):
                UUTestLog("Got \(urls.count) URLs,\n\n\(urls.joined(separator: "\n"))")
                XCTAssertGreaterThan(urls.count, 0)
            
            case .failure(let error):
                XCTFail("\(error)")
        }*/
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
