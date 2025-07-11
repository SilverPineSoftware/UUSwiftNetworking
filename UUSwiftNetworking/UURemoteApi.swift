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
    private var session: UUHttpSession!
    
    private var isAuthorizingFlag: Bool = false
    private var isAuthorizingFlagLock = NSRecursiveLock()
    
    private var authorizeListeners : [(Bool,Error?)->()] = []
    private var authorizeListenersLock = NSRecursiveLock()
    
    // MARK: Public Methods
    
    public convenience init(configuration: URLSessionConfiguration, delegate: URLSessionDelegate)
    {
        self.init(session: UUHttpSession(configuration: configuration, delegate: delegate))
    }
    
    public init(session: UUHttpSession = UUHttpSession())
    {
        self.session = session
    }
    
    /**
     Executes a single request with api authorization handling wrapped in.  Prior to making the request, a check is done to see if Api renewal is needed.
     Also, if an error is returned, a check is done to determine if the error requires api authorization renewal.  After perforaming any api authorization renewal,
     the original request will be tried again
     */
    public func executeRequest(_ request: UUHttpRequest, _ completion: @escaping (UUHttpResponse)->())
    {
        renewApiAuthorizationIfNeeded
        { _, authorizationRenewalError in
            
            if (authorizationRenewalError != nil)
            {
                let response = UUHttpResponse(request: request, response: nil, error: authorizationRenewalError)
                completion(response)
                return
            }
            
            self.executeOneRequest(request)
            { response in
                
                if let err = response.httpError,
                   self.shouldRenewApiAuthorization(err)
                {
                    self.internalRenewApiAuthorization
                    { didAttempt, innerAuthorizationRenewalError in
                        
                        if (innerAuthorizationRenewalError != nil)
                        {
                            let response = UUHttpResponse(request: request, response: nil, error: innerAuthorizationRenewalError)
                            completion(response)
                        }
                        else
                        {
                            if (didAttempt)
                            {
                                self.executeOneRequest(request, completion)
                            }
                            else
                            {
                                completion(response)
                            }
                        }
                    }
                }
                else
                {
                    completion(response)
                }
            }
        }
    }
    
    /**
     Executes a single request with no api authorization checks
     */
    public func executeOneRequest(_ request: UUHttpRequest, _ completion: @escaping (UUHttpResponse)->())
    {
        _ = session.executeRequest(request, completion)
    }
    
    // MARK: Public Overridable Methods
    
    /**
     Perform an api authorization/renewal.  Typically this means fetching a JWT from a server,.
     
     Default behavior is to just return nil
     */
    open func renewApiAuthorization(_ completion: @escaping (Bool,Error?)->())
    {
        completion(false, nil)
    }

    /**
     Returns whether api authorization is needed ahead of making an actual api call.  Typically this means checking a JWT expiration
     
     Default behavior is to return false
     */
    open func isApiAuthorizationNeeded(_ completion: @escaping (Bool)->())
    {
        completion(false)
    }
    
    /**
     Determines if api authorization is needed based on an Error
     
     Default behavior is to return  true if the UUHttpSessionError is authorizationNeeded.
     */
    open func shouldRenewApiAuthorization(_ error: Error) -> Bool
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
    
    private func renewApiAuthorizationIfNeeded(_ completion: @escaping (Bool, Error?)->())
    {
        isApiAuthorizationNeeded
        { authorizationNeeded in
            
            if (authorizationNeeded)
            {
                self.internalRenewApiAuthorization(completion)
            }
            else
            {
                completion(false, nil)
            }
        }
    }
    
    private func internalRenewApiAuthorization(_ completion: @escaping (Bool, Error?)->())
    {
        addAuthorizeListener(completion)
        
        let isAuthorizing = self.isAuthorizing()
        
        if (isAuthorizing)
        {
            return
        }
        
        setAuthorizing(true)
        
        renewApiAuthorization
        { didAttempt, error in
            self.notifyAuthorizeListeners(didAttempt, error)
        }
    }
    
    private func setAuthorizing(_ val: Bool)
    {
        defer { isAuthorizingFlagLock.unlock() }
        isAuthorizingFlagLock.lock()
        
        isAuthorizingFlag = val
    }
    
    private func isAuthorizing() -> Bool
    {
        defer { isAuthorizingFlagLock.unlock() }
        isAuthorizingFlagLock.lock()
        
        return isAuthorizingFlag
    }
    
    private func addAuthorizeListener(_ listener: @escaping (Bool,Error?)->())
    {
        defer { authorizeListenersLock.unlock() }
        authorizeListenersLock.lock()
        
        authorizeListeners.append(listener)
    }
    
    private func notifyAuthorizeListeners(_ didAttempt: Bool, _ error: Error?)
    {
        defer { authorizeListenersLock.unlock() }
        authorizeListenersLock.lock()
        
        var listenersToNotify: [(Bool, Error?)->()] = []
        listenersToNotify.append(contentsOf: authorizeListeners)
        authorizeListeners.removeAll()
        
        // At this point, authorize is done, we have the response error,
        // and if a new call to authorize comes in, we want it allow it
        setAuthorizing(false)
        
        listenersToNotify.forEach
        { listener in
            
            DispatchQueue.global(qos: .default).async
            {
                listener(didAttempt, error)
            }
        }
    }
}
