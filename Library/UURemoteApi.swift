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
    public var session: UUHttpSession = UUHttpSession()
    public var authorizationProvider: UUHttpAuthorizationProvider? = nil
    
    // MARK: Public Methods

    public init()
    {
        
    }
    
    /**
     Executes a single request with api authorization handling wrapped in.  Prior to making the request, a check is done to see if Api renewal is needed.
     Also, if an error is returned, a check is done to determine if the error requires api authorization renewal.  After perforaming any api authorization renewal,
     the original request will be tried again
     */
    open func executeRequest(_ request: UUHttpRequest) async -> UUHttpResponse
    {
        let renewResult = await renewApiAuthorizationIfNeeded()
        if let authorizationRenewalError = renewResult.error
        {
            return UUHttpResponse(request: request, response: nil, error: authorizationRenewalError)
        }
        
        await prepareRequest(request)
        var response = await session.executeRequest(request)
        if let err = response.httpError, await shouldRenewApiAuthorization(err)
        {
            let innerRenewResult = await internalRenewApiAuthorization()
            if let innerAuthorizationRenewalError = innerRenewResult.error
            {
                return UUHttpResponse(request: request, response: nil, error: innerAuthorizationRenewalError)
            }
            
            if (innerRenewResult.didAttempt)
            {
                // Prepare again (assuming authorization has changed)
                await prepareRequest(request)
                response = await session.executeRequest(request)
            }
        }
        
        return response
    }
    
    open func prepareRequest(_ request: UUHttpRequest) async
    {
        if (request.authorizationProvider == nil)
        {
            request.authorizationProvider = self.authorizationProvider
        }
    }
    
    open func executeCodableRequest<SuccessType: Codable, ErrorType: Codable>(
        _ request: UUCodableHttpRequest<SuccessType, ErrorType>) async -> Result<SuccessType, Error>
    {
        let renewResult = await renewApiAuthorizationIfNeeded()
        if let authorizationRenewalError = renewResult.error
        {
            return .failure(authorizationRenewalError)
        }
        
        await prepareRequest(request)
        var result = await session.executeCodableRequest(request)
        switch (result)
        {
            case .success(let success):
                return .success(success)
            
            case .failure(let error):
            
                if (await shouldRenewApiAuthorization(error))
                {
                    let innerRenewResult = await internalRenewApiAuthorization()
                    if let innerAuthorizationRenewalError = innerRenewResult.error
                    {
                        return .failure(innerAuthorizationRenewalError)
                    }
                    
                    if (innerRenewResult.didAttempt)
                    {
                        // Prepare again (assuming authorization has changed)
                        await prepareRequest(request)
                        result = await session.executeCodableRequest(request)
                    }
                }
            
            return result
        }
    }
    
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

        var coalescedWaiterCount: Int
        {
            waiters.count
        }
    }

    /// Visible to unit tests via `@testable import` for renewal coalescing assertions.
    internal func renewalCoalescedWaiterCount() async -> Int
    {
        await renewalGate.coalescedWaiterCount
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
