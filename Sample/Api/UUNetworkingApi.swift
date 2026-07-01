//
//  UUNetworkingApi.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/29/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import UUSwiftCore
import UUSwiftNetworking

protocol UUNetworkingApi
{
    // Returns the URL that the app needs to open in a secure web browser to log the user into the application.
    func getLoginUrl() async -> Result<URL, Error>
}

nonisolated
class UUNetworkingApiImpl: UURemoteApi, UUNetworkingApi
{
    
    
    func getLoginUrl() async -> Result<URL, any Error>
    {
        let state = UURandom.bytes(length: 32).uuToHexString()
        let pkce = UUPKCE.generate()
        
        //let callbackUrl = "https://uu-static.spsw.io/login"
        let callbackUrl = "uu-networking://login"
        let callbackUrlScheme = callbackUrl.uuUrlScheme
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "sso.spsw.dev"
        urlComponents.path = "/mobile/authorize"
        urlComponents.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: "uu-networking-sample"),
            URLQueryItem(name: "redirect_uri", value: callbackUrl),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.challengeMethod),
        ]
        
        guard let url = urlComponents.url else
        {
            NSLog("ERROR! Unable to create URL")
            return .failure(URLError(.badURL))
        }
        
        return .success(url)
        
    }
}
