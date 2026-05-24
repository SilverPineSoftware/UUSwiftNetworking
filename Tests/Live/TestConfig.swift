//
//  TestConfig.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/23/26.
//

import Foundation

public struct TestConfig: Codable, CustomStringConvertible
{
    let apiHost: String
    let staticFilesUrl: String
    let doesNotExistUrl: String
    let uploadImageFileName: String
    let downloadImageFileName: String
    
    public var description: String
    {
        return "apiHost: \(apiHost), staticFilesUrl: \(staticFilesUrl), doesNotExistUrl: \(doesNotExistUrl), uploadImageFileName: \(uploadImageFileName)"
    }
    
    enum CodingKeys: String, CodingKey
    {
        case apiHost = "api_host"
        case staticFilesUrl = "static_files_url"
        case doesNotExistUrl = "does_not_exist_url"
        case uploadImageFileName = "upload_image_file_name"
        case downloadImageFileName = "download_image_file_name"
    }
    
    static func load(from file: String) -> TestConfig?
    {
        guard let url = Bundle.module.url(forResource: file, withExtension: "json") else
        {
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else
        {
            return nil
        }
        
        let config = try? JSONDecoder().decode(TestConfig.self, from: data)
        NSLog("Config: \(String(describing: config))")
        return config
    }
    
    var timeoutUrl: String
    {
        return "\(apiHost)/timeout.php"
    }
    
    var echoJsonUrl: String
    {
        return "\(apiHost)/echo_json.php"
    }
    
    /// Routed `EchoController` (`GET` / `POST` / `PUT` on `/echo/json`).
    var echoControllerJsonUrl: String
    {
        return "\(apiHost)/echo/json"
    }
    
    var invalidJsonUrl: String
    {
        return "\(apiHost)/invalid_json.php"
    }
    
    var redirectUrl: String
    {
        return "\(apiHost)/redirect.php"
    }
    
    var formPostUrl: String
    {
        return "\(apiHost)/form.php"
    }
    
    var downloadFileUrl: String
    {
        return "\(apiHost)/download.php"
    }
    
    var fullDownloadFileUrl: String
    {
        return "\(staticFilesUrl)/downloads/\(downloadImageFileName)"
    }
    
    var uploadImageFilePath: URL?
    {
        let namePart = uploadImageFileName.uuGetFileName()
        let extPart = uploadImageFileName.uuGetFileExtension()
        let nameOnly = namePart.replacingOccurrences(of: ".\(extPart)", with: "")
        
        let path = Bundle.module.url(forResource: nameOnly, withExtension: extPart)
        return path
    }
}
