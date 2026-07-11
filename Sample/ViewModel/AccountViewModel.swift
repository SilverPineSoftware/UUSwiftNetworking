//
//  AccountViewModel.swift
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

private let LOG_TAG = "AccountViewModel"

@MainActor
class AccountViewModel: ObservableObject
{
    // Published data elements
    @Published var user: AppUser? = nil
    @Published var error: AppError? = nil
    @Published var isLoading: Bool = false
    @Published var isLoggedIn: Bool = false
    
    // Injectable app services
    let api: AppServerApi
    
    // Private temporary variables
    private var session: ASWebAuthenticationSession? = nil
    private let context = SsoPresentationAnchor()
    private var loginRequest: LoginRequest? = nil

    init(api: AppServerApi = AppServices.appServer)
    {
        self.api = api
    }
    
    func refresh() async
    {
        let result = await api.getMe()
        UULog.debug(tag: LOG_TAG, message: "getMe returned: \(result)")
        handleUserResult(result)
    }
    
    func ssoLogin() async
    {
        let req = LoginRequest()
        
        let loginResult = await api.getLoginUrl(req)
        
        let url: URL
        switch (loginResult)
        {
            case .success(let loginUrl):
                url = loginUrl
            
            case .failure(let err):
                UULog.debug(tag: LOG_TAG, message: "Failed to get login URL: \(err)")
                return
        }
        
        DispatchQueue.main.async
        {
            UULog.debug(tag: LOG_TAG, message: "Opening SSO Login URL: \(url)")
            
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: req.callbackUrl.uuUrlScheme,
                completionHandler: { callbackUrl, callbackError in
                    
                    UULog.debug(tag: LOG_TAG, message: "SSO Callback URL: \(String(describing: callbackUrl))")
                    UULog.debug(tag: LOG_TAG, message: "SSO Callback Error: \(String(describing: callbackError))")
                    
                    if let err = callbackError
                    {
                        // Show Error
                        UULog.debug(tag: LOG_TAG, message: "Login Failure: \(err)")
                    }
                    else if let url = callbackUrl
                    {
                        Task
                        {
                            await self.finishLogin(url)
                        }
                    }
                })
        
        
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self.context
            self.session = session
            self.loginRequest = req
            let started = session.start()
            UULog.debug(tag: LOG_TAG, message: "ASWebAuthenticationSession started: \(started)")
        }
    }
    
    func finishLogin(_ url: URL) async
    {
        // Clear login temporary variables when this method finishes
        defer
        {
            self.loginRequest = nil
        }
        
        self.session?.cancel()
        self.session = nil
        
        guard let loginRequest = self.loginRequest else
        {
            UULog.debug(tag: LOG_TAG, message: "Login request not set")
            return
        }
        
        let result = await api.completeLogin(loginRequest, url)
        UULog.debug(tag: LOG_TAG, message: "complete login result: \(result)")
        handleUserResult(result)
    }
    
    private func handleUserResult(_ result: Result<AppUser, AppError>)
    {
        switch (result)
        {
            case .success(let user):
                self.error = nil
                self.user = user
            
            case .failure(let err):
                self.error = err
                self.user = nil
        }
        
        self.isLoggedIn = (self.user != nil)
    }
    
    func ssoLogout() async
    {
        let err = await api.logout()
        UULog.debug(tag: LOG_TAG, message: "Logout complete.  Error: \(err?.localizedDescription ?? "none")")
        self.user = nil
        self.error = nil
    }
}
