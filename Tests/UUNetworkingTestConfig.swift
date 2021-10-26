//
//  UUNetworkingTestConfig.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/19/21.
//

import Foundation
import XCTest

class UUNetworkingTestConfig
{
    var testServerApiHost: String = ""
    var doesNotExistUrl: String = ""
    var uploadFilePath: URL? = nil
    
    required init(plistFile: String)
    {
        if let path = Bundle.module.url(forResource: plistFile, withExtension: "plist")
        {
            if let d = NSDictionary(contentsOf: path) as? [AnyHashable:Any]
            {
                if let str = d["test_server_api_host"] as? String
                {
                    testServerApiHost = str
                }
                
                if let str = d["does_not_exist_url"] as? String
                {
                    doesNotExistUrl = str
                }
                
                if let fullFileName = d["upload_image_file_name"] as? String
                {
                    let namePart = fullFileName.uuGetFileName()
                    let extPart = fullFileName.uuGetFileExtension()
                    let nameOnly = namePart.replacingOccurrences(of: ".\(extPart)", with: "")
                    
                    if let path = Bundle.module.url(forResource: nameOnly, withExtension: extPart)
                    {
                        uploadFilePath = path
                    }
                }
            }
        }
    }
    
    var timeoutUrl: String
    {
        return "\(testServerApiHost)/timeout.php"
    }
    
    var echoJsonUrl: String
    {
        return "\(testServerApiHost)/echo_json.php"
    }
    
    var invalidJsonUrl: String
    {
        return "\(testServerApiHost)/invalid_json.php"
    }
    
    var redirectUrl: String
    {
        return "\(testServerApiHost)/redirect.php"
    }
    
    var formPostUrl: String
    {
        return "\(testServerApiHost)/form.php"
    }
    
    var downloadFileUrl: String
    {
        return "\(testServerApiHost)/download.php"
    }
}


func UULoadNetworkingTestConfig() -> UUNetworkingTestConfig
{
    let cfg = UUNetworkingTestConfig(plistFile: "UUNetworkingTestConfig")
    
    XCTAssertFalse(cfg.testServerApiHost.isEmpty, "Expected a valid test server api host")
    XCTAssertFalse(cfg.doesNotExistUrl.isEmpty, "Expected a valid does not exist url")
    
    return cfg
}
