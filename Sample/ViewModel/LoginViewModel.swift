//
//  LoginViewModel.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/25/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import UUSwiftNetworking
import AuthenticationServices
import UUSwiftCore
import CryptoKit

private let LOG_TAG = "LoginViewModel"

@MainActor
class LoginViewModel: ObservableObject
{
//    @Published var showConfig: Bool = false
//    @Published var searchQuery: String = "labrador"
//    @Published var imageUrls: [String] = []
    @Published var isLoading: Bool = false
    
    private var session: ASWebAuthenticationSession? = nil
    //private var codeChallenge: String? = nil
    private var state: String? = nil
    private var pkce: UUPKCE? = nil

    init()
    {
//        let cfg = ShutterstockApiConfig.load()
//        clientKey = cfg.clientKey
//        clientSecret = cfg.clientSecret
    }

    func ssoLogin() async //_ session: WebAuthenticationSession) async
    {
        self.state = UURandom.bytes(length: 32).uuToHexString()
        let pkce = UUPKCE.generate()
        
        let callbackUrl = "https://uu-static.spsw.io/login"
        
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
        
        //let url = "https://sso.spsw.dev/authorize?response_type=code&client_id=uu-networking-sample&redirect_uri=uu%3A%2F%2Fnetworking.sample%2Flogin&scope=openid+email+profile&state=REPLACE_WITH_STATE&code_challenge=REPLACE_WITH_PKCE_CODE_CHALLENGE&code_challenge_method=S256"
        guard let url = urlComponents.url else
        {
            NSLog("ERROR! Unable to create URL")
            return
        }
        
        DispatchQueue.main.async
        {
            let context = SsoPresentationAnchor()
            
            UULog.debug(tag: LOG_TAG, message: "Opening SSO Login URL: \(url)")
            
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "https",
                completionHandler: { callbackUrl, callbackError in
                    
                    UULog.debug(tag: LOG_TAG, message: "SSO Callback URL: \(String(describing: callbackUrl))")
                    UULog.debug(tag: LOG_TAG, message: "SSO Callback Error: \(String(describing: callbackError))")
                    
                    //continuation.resume(returning: callbackError)
                })
        
        
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = context
            self.session = session
            self.pkce = pkce
            session.start()
        }
    }
    
    func finishLogin(_ url: URL)
    {
        // Clear login temporary variables when this method finishes
        defer
        {
            self.session = nil
            self.state = nil
            self.pkce = nil
        }
        
        self.session?.cancel()
        self.session = nil
        
        guard let stateCheck = self.state else
        {
            UULog.debug(tag: LOG_TAG, message: "Login state not set")
            return
        }
        
        guard let pkce = self.pkce else
        {
            UULog.debug(tag: LOG_TAG, message: "PKCE not set")
            return
        }
        
        let urlPath = url.path(percentEncoded: false)
        UULog.debug(tag: LOG_TAG, message: "URLPath: \(urlPath)")
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let ticketItem = queryItems.first(where: { $0.name == "ticket" }),
           let ticket = ticketItem.value,
           let stateItem = queryItems.first(where: { $0.name == "state" }),
           let state = stateItem.value
        {
            UULog.debug(tag: LOG_TAG, message: "Ticket: \(ticket)")
            UULog.debug(tag: LOG_TAG, message: "State: \(state)")
            
            if (state != stateCheck)
            {
                UULog.debug(tag: LOG_TAG, message: "State check failed!, expected: \(stateCheck) but received: \(state)")
                return
            }
            
            var urlComponents = URLComponents()
            urlComponents.scheme = "https"
            urlComponents.host = "sso.spsw.dev"
            urlComponents.path = "/mobile/complete"
            
            guard let url = urlComponents.url else
            {
                NSLog("ERROR! Unable to create URL")
                return
            }
            
            let req = LoginCompleteRequest(clientId: "uu-networking-sample", ticket: ticket, codeVerifier: pkce.codeVerifier)
            
            Task
            {
                let result = await UUHttpSession.post(url: url.absoluteString, body: UUJsonBody(req))
                if let error = result.httpError
                {
                    UULog.debug(tag: LOG_TAG, message: "Error: \(error)")
                }
                else if let appResponse = result.parsedResponse as? Data
                {
                    UULog.debug(tag: LOG_TAG, message: "\(String(describing: String(data: appResponse, encoding: .utf8)))")
                }
                else
                {
                    UULog.debug(tag: LOG_TAG, message: "Unknown response type")
                }
            }
        }
        
    }
}

struct LoginCompleteRequest: Codable
{
    let clientId: String
    let ticket: String
    let codeVerifier: String
    
    init(clientId: String, ticket: String, codeVerifier: String)
    {
        self.clientId = clientId
        self.ticket = ticket
        self.codeVerifier = codeVerifier
    }
    
    enum CodingKeys: String, CodingKey
    {
        case clientId = "client_id"
        case ticket
        case codeVerifier = "code_verifier"
    }
}

