//
//  BaseOnlineTest.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/23/26.
//

import XCTest
import Testing
import UUSwiftCore
import UUSwiftTestCore
@testable import UUSwiftNetworking

open class BaseOnlineTest: XCTestCase
{
    var testConfig: TestConfig!
    
//    open override func setUp()
//    {
//        super.setUp()
//        
//        let logger = UULogger.console
//        logger.logLevel = .debug
//        UULog.setLogger(logger)
//    }
    
    open override func setUpWithError() throws
    {
        try super.setUpWithError()
        
        let logger = UULogger.console
        logger.logLevel = .debug
        UULog.setLogger(logger)
        
        testConfig = try XCTUnwrap(TestConfig.load(from: "TestConfig"))
    }
    
    /*open func loadTestConfig() throws -> TestConfig
    {
        if let testConfig = testConfig
        {
            return testConfig
        }
        
        let cfg = TestConfig.load(from: "TestConfig")
        self.testConfig = cfg
        return try XCTUnwrap(self.testConfig)
    }*/
    
    open var uuHttpSessionForTest: UUHttpSession
    {
        return UUHttpSession()
    }
}
