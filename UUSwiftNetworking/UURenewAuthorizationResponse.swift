//
//  UURenewAuthorizationResponse.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import Foundation

public struct UURenewAuthorizationResponse: @unchecked Sendable
{
    public let didAttempt: Bool
    public let error: (any Error)?
    
    public init(didAttempt: Bool, error: Error?)
    {
        self.didAttempt = didAttempt
        self.error = error
    }
}
