//
//  BaseOnlineTest.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/23/26.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

@testable import UUSwiftNetworking

open class BaseOnlineTest: XCTestCase
{
    private var testConfig: TestConfig? = nil
    
    open override func setUp()
    {
        super.setUp()
        
        let logger = UULogger.console
        logger.logLevel = .debug
        UULog.setLogger(logger)
    }
    
    open func loadTestConfig() throws -> TestConfig
    {
        if let testConfig = testConfig
        {
            return testConfig
        }
        
        let cfg = TestConfig.load(from: "TestConfig")
        self.testConfig = cfg
        return try XCTUnwrap(self.testConfig)
    }
    
    open var uuHttpSessionForTest: UUHttpSession
    {
        return UUHttpSession()
    }
}
