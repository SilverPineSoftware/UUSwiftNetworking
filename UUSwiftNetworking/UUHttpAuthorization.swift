//
//  UUHttpAuthorization.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/22/21.
//

import Foundation

public protocol UUHttpAuthorizationProvider
{
    func attachAuthorization(to request: UUHttpRequest)
}

open class UUTokenAuthorizationProvider: UUHttpAuthorizationProvider
{
    public init()
    {
        
    }
    
    open func attachAuthorization(to request: UUHttpRequest)
    {
        if let token = authorizationToken
        {
            request.headerFields["Authorization"] = "Bearer \(token)"
        }
    }
    
    open var authorizationToken: String?
    {
        get
        {
            return nil
        }
    }
}
