//
//  UURemoteData.swift
//  Useful Utilities - An extension to Useful Utilities 
//  UUDataCache that fetches data from a remote source
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//
//
//  UURemoteData provides a centralized place where application components can 
//  request data that may come from a remote source.  It utilizes existing 
//  UUDataCache functionality to locally store files for later fetching.  It 
//  will intelligently handle multiple requests for the same image so that 
//  extraneous network requests are not needed.
//
//  NOTE: This class depends on the following toolbox classes:
//
//  UUHttpSession
//  UUDataCache
//

#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

import UUSwiftCore

fileprivate let LOG_TAG = "UURemoteData"

public protocol UURemoteDataProtocol
{
    func data(for key: String) -> Data?
    func isDownloadActive(for key: String) -> Bool
    
    func metaData(for key: String) -> [String:Any]
    func set(metaData: [String:Any], for key: String)
}

public typealias UUDataLoadedCompletionBlock = (Data?, Error?) -> Void

public class UURemoteData: UURemoteDataProtocol
{
    public struct Notifications
    {
        public static let DataDownloaded = Notification.Name("UUDataDownloadedNotification")
        public static let DataDownloadFailed = Notification.Name("UUDataDownloadFailedNotification")
    }

    public struct MetaData
    {
        public static let MimeType = "MimeType"
        public static let DownloadTimestamp = "DownloadTimestamp"
    }
    
    public struct NotificationKeys
    {
        public static let RemotePath = "UUDataRemotePathKey"
        public static let Error = "UURemoteDataErrorKey"
    }

	private var activeDownloads : [String : UUHttpRequest] = [:]
    private var activeDownloadsLock = NSRecursiveLock()
    
    private var pendingDownloads : [String] = []
    private var pendingDownloadsLock = NSRecursiveLock()
    
	private var httpRequestLookups : [String : [UUDataLoadedCompletionBlock]] = [:]
    private var httpRequestLookupsLock = NSRecursiveLock()
    
    // Default to 4 active requests at a time...
    public var maxActiveRequests: Int = 4
    
    public var networkTimeout: TimeInterval = UUHttpRequest.defaultTimeout
    
    // Optional hook to provide an instance of UURemoteApi.  When set UURemoteData sends
    // requests through the remoteApi
    let remoteApi: UURemoteApi
    let dataCache: UUDataCache
    
    static public let shared = UURemoteData(dataCache: UUDataCache.shared, remoteApi: UURemoteApi())
    
    required init(dataCache: UUDataCache, remoteApi: UURemoteApi)
    {
        self.dataCache = dataCache
        self.remoteApi = remoteApi
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // UURemoteDataProtocol Implementation
    ////////////////////////////////////////////////////////////////////////////
    public func data(for key: String) -> Data?
    {
        return data(for: key, remoteLoadCompletion: nil)
    }
    
    public func data(for key: String, remoteLoadCompletion: UUDataLoadedCompletionBlock? = nil) -> Data?
    {
        let url = URL(string: key)
        if (url == nil)
        {
            return nil
        }
        
		if dataCache.dataExists(for: key)
        {
			let data = dataCache.data(for: key)
			if (data != nil)
			{
				return data
			}
        }
        
        if (self.isDownloadActive(for: key))
        {
            // An active UUHttpSession means a request is currently fetching the resource, so
            // no need to re-fetch
            //UUDebugLog("Download pending for \(key)")
            self.appendRemoteHandler(for: key, handler: remoteLoadCompletion)

            return nil
        }
        
        if (self.activeDownloadCount() > self.maxActiveRequests)
        {
            self.queuePendingRequest(for: key, remoteLoadCompletion: remoteLoadCompletion)
            return nil
        }
        
        let request = UUHttpRequest(url: key)
        request.responseHandler = UUPassthroughResponseHandler()
        request.timeout = networkTimeout
        
        remoteApi.executeRequest(request)
        { response in
            self.handleDownloadResponse(response, key)
            self.checkForPendingRequests()
        }

		self.setActiveDownload(request, forKey: key)
        self.appendRemoteHandler(for: key, handler: remoteLoadCompletion)
        
        return nil
    }
    
    private func checkForPendingRequests()
    {
        while (activeDownloadCount() < self.maxActiveRequests)
        {
            guard let next = self.dequeuePending() else
            {
                break
            }
            
            _ = self.data(for: next)
        }
    }

    public func metaData(for key: String) -> [String:Any]
    {
        return dataCache.metaData(for: key)
    }
    
    public func set(metaData: [String:Any], for key: String)
    {
        dataCache.set(metaData: metaData, for: key)
    }

    ////////////////////////////////////////////////////////////////////////////
    // Private Implementation
    ////////////////////////////////////////////////////////////////////////////
    private func handleDownloadResponse(_ response: UUHttpResponse, _ key: String)
    {
        defer { httpRequestLookupsLock.unlock() }
        httpRequestLookupsLock.lock()
        
        var md : [String:Any] = [:]
        md[UURemoteData.NotificationKeys.RemotePath] = key
        
        if (response.httpError == nil && response.rawResponse != nil)
        {
            let responseData = response.rawResponse!
            
            dataCache.set(data: responseData, for: key)
            updateMetaDataFromResponse(response, for: key)
            notifyDataDownloaded(metaData: md)
            
            if let handlers = self.httpRequestLookups[key]
            {
                notifyRemoteDownloadHandlers(key: key, data: responseData, error: nil, handlers: handlers)
            }
        }
        else
        {
            UULog.debug(tag: LOG_TAG, message: "Remote download failed!\n\nPath: \(key)\nStatusCode: \(String(describing: response.httpResponse?.statusCode))\nError: \(String(describing: response.httpError))\n")
            
            md[NotificationKeys.Error] = response.httpError
            
            DispatchQueue.main.async
            {
                NotificationCenter.default.post(name: Notifications.DataDownloadFailed, object: nil, userInfo: md)
            }
            
            if let handlers = self.httpRequestLookups[key]
            {
                notifyRemoteDownloadHandlers(key: key, data: nil, error: response.httpError, handlers: handlers)
            }
        }

		self.removeDownload(forKey: key)
        _ = self.httpRequestLookups.removeValue(forKey: key)
    }
    
    private func updateMetaDataFromResponse(_ response: UUHttpResponse, for key: String)
    {
        var md = dataCache.metaData(for: key)
        md[MetaData.MimeType] = response.httpResponse!.mimeType!
        md[MetaData.DownloadTimestamp] = Date()
        
        dataCache.set(metaData: md, for: key)
    }
    
    public func save(data: Data, key: String)
    {
        dataCache.set(data: data, for: key)
        
        var md = dataCache.metaData(for: key)
        md[MetaData.MimeType] = "raw"
        md[MetaData.DownloadTimestamp] = Date()
        md[UURemoteData.NotificationKeys.RemotePath] = key
        
        dataCache.set(metaData: md, for: key)
        
        notifyDataDownloaded(metaData: md)
    }
    
    private func notifyDataDownloaded(metaData: [String:Any])
    {
        DispatchQueue.main.async
        {
            NotificationCenter.default.post(name: Notifications.DataDownloaded, object: nil, userInfo: metaData)
        }
    }
    
    private func notifyRemoteDownloadHandlers(key: String, data: Data?, error: Error?, handlers: [UUDataLoadedCompletionBlock])
    {
        for handler in handlers
        {
            DispatchQueue.main.async
            {
                handler(data, error)
            }
        }
    }
    
}

extension UURemoteData
{
	private func setActiveDownload(_ request : UUHttpRequest, forKey: String)
    {
        defer { activeDownloadsLock.unlock() }
        activeDownloadsLock.lock()
        
        self.activeDownloads[forKey] = request
	}

	private func removeDownload(forKey: String)
    {
        defer { activeDownloadsLock.unlock() }
        activeDownloadsLock.lock()
        
        _ = self.activeDownloads.removeValue(forKey: forKey)
	}

	private func activeDownloadCount() -> Int
	{
        defer { activeDownloadsLock.unlock() }
        activeDownloadsLock.lock()
        
        return self.activeDownloads.count
	}

	public func isDownloadActive(for key: String) -> Bool
	{
        defer { activeDownloadsLock.unlock() }
        activeDownloadsLock.lock()
        
		return (activeDownloads[key] != nil)
	}

	private func pendingDownloadCount() -> Int
	{
        defer { pendingDownloadsLock.unlock() }
        pendingDownloadsLock.lock()
        
		return self.pendingDownloads.count
	}

	private func dequeuePending() -> String?
	{
        defer { pendingDownloadsLock.unlock() }
        pendingDownloadsLock.lock()
        
		return self.pendingDownloads.popLast()
	}

	private func queuePendingRequest(for key: String, remoteLoadCompletion: UUDataLoadedCompletionBlock?)
	{
        defer { pendingDownloadsLock.unlock() }
        pendingDownloadsLock.lock()
        
        if let index = self.pendingDownloads.firstIndex(of: key)
        {
            self.pendingDownloads.remove(at: index)
        }
        
        self.pendingDownloads.insert(key, at: 0)
		
		appendRemoteHandler(for: key, handler: remoteLoadCompletion)
	}

	private func appendRemoteHandler(for key: String, handler: UUDataLoadedCompletionBlock?)
	{
        defer { httpRequestLookupsLock.unlock() }
        httpRequestLookupsLock.lock()
        
        if let remoteHandler = handler
        {
            var handlers = self.httpRequestLookups[key]
            if (handlers == nil)
            {
                handlers = []
            }

            if (handlers != nil)
            {
                handlers!.append(remoteHandler)
                self.httpRequestLookups[key] = handlers!
            }
        }
	}
}

extension Notification
{
    public var uuRemoteDataPath : String?
    {
        return userInfo?[UURemoteData.NotificationKeys.RemotePath] as? String
    }
    
    public var uuRemoteDataError : Error?
    {
        return userInfo?[UURemoteData.NotificationKeys.Error] as? Error
    }
}
