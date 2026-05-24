//
//  UURemoteApi.swift
//  Useful Utilities - Base class for RESTful api's
//  
//
//  Created by Ryan DeVore on 10/20/21.
//

import Foundation

open class UURemoteApi
{
    private let session: UUHttpSession
    
    // MARK: Public Methods
    
    public init(session: UUHttpSession = UUHttpSession())
    {
        self.session = session
    }
    
    /**
     Executes a single request with api authorization handling wrapped in.  Prior to making the request, a check is done to see if Api renewal is needed.
     Also, if an error is returned, a check is done to determine if the error requires api authorization renewal.  After perforaming any api authorization renewal,
     the original request will be tried again
     */
    public func executeRequest(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        let renewResult = await renewApiAuthorizationIfNeeded()
        if let authorizationRenewalError = renewResult.error
        {
            return UUHttpResponse(request: request, response: nil, error: authorizationRenewalError)
        }
        
        var response = await executeOneRequest(request)
        if let err = response.httpError, await shouldRenewApiAuthorization(err)
        {
            let innerRenewResult = await internalRenewApiAuthorization()
            if let innerAuthorizationRenewalError = innerRenewResult.error
            {
                return UUHttpResponse(request: request, response: nil, error: innerAuthorizationRenewalError)
            }
            
            if (innerRenewResult.didAttempt)
            {
                response = await executeOneRequest(request)
            }
        }
        
        return response
    }
    
    /**
     Executes a single request with no api authorization checks
     */
    open func executeOneRequest(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        return await session.executeRequest(request)
    }
    
    // MARK: Public Overridable Methods
    
    /**
     Perform an api authorization/renewal.  Typically this means fetching a JWT from a server,.
     
     Default behavior is to just return nil
     */
    open func renewApiAuthorization() async -> UURenewAuthorizationResponse
    {
        return UURenewAuthorizationResponse(didAttempt: false, error: nil)
    }

    /**
     Returns whether api authorization is needed ahead of making an actual api call.  Typically this means checking a JWT expiration
     
     Default behavior is to return false
     */
    open func isApiAuthorizationNeeded() async -> Bool
    {
        return false
    }
    
    /**
     Determines if api authorization is needed based on an Error
     
     Default behavior is to return  true if the UUHttpSessionError is authorizationNeeded.
     */
    open func shouldRenewApiAuthorization(_ error: Error) async -> Bool
    {
        guard let errorCode = error.uuHttpErrorCode else
        {
            return false
        }
        
        return (errorCode == .authorizationNeeded)
    }
    
    open func cancelAll()
    {
        session.cancelAll()
    }
    
    // MARK: Private Implementation
    
    private func renewApiAuthorizationIfNeeded() async -> UURenewAuthorizationResponse
    {
        guard await isApiAuthorizationNeeded() else
        {
            return UURenewAuthorizationResponse(didAttempt: false, error: nil)
        }
        
        return await internalRenewApiAuthorization()
    }
    
    private let renewalGate = RenewalGate()

    private actor RenewalGate
    {
        private var inFlight = false
        private var waiters: [CheckedContinuation<UURenewAuthorizationResponse, Never>] = []

        /// Returns a coalesced result when renewal is already in flight; `nil` means this caller is the leader.
        func begin() async -> UURenewAuthorizationResponse?
        {
            if inFlight
            {
                return await withCheckedContinuation { waiters.append($0) }
            }
            inFlight = true
            return nil
        }

        func finish(_ result: UURenewAuthorizationResponse) -> UURenewAuthorizationResponse
        {
            inFlight = false
            let pending = waiters
            waiters.removeAll()
            for waiter in pending
            {
                waiter.resume(returning: result)
            }
            return result
        }
    }

    private func internalRenewApiAuthorization() async -> UURenewAuthorizationResponse
    {
        if let coalesced = await renewalGate.begin()
        {
            return coalesced
        }

        let result = await renewApiAuthorization()
        return await renewalGate.finish(result)
    }
}
