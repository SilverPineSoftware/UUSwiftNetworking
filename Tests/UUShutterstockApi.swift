//
//  UURemoteDataTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/18/21.
//

import Foundation
import UUSwiftCore
import UUSwiftNetworking
import UUSwiftTestCore

class UUShutterstockApi
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
        
        UUTestLog("Fetching page \(page)")
        _ = UUHttpSession.executeRequest(req)
        { (response: UUHttpResponse) in
        
            var results: [String] = []
            
            if (response.httpError == nil)
            {
                if let parsed = response.parsedResponse as? [AnyHashable:Any],
                   let data = parsed.uuGetDictionaryArray("data")
                {
                    for item in data
                    {
                        if let assets = item.uuGetDictionary("assets")
                        {
                            //small_thumb
                            //large_thumb
                            //huge_thumb
                            //preview
                            //preview_1000
                            //preview_1500
                            
                            if let d = assets.uuGetDictionary(assetKey),
                               let url = d.uuGetString("url")
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
