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

import Foundation
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

private struct CoalescedDownloadResponse: @unchecked Sendable
{
    let response: UUHttpResponse
}

private actor UURemoteDataPendingQueue
{
    private var pendingDownloads: [String] = []

    func queuePending(for key: String)
    {
        if let index = pendingDownloads.firstIndex(of: key)
        {
            pendingDownloads.remove(at: index)
        }

        pendingDownloads.insert(key, at: 0)
    }

    func dequeuePending() -> String?
    {
        pendingDownloads.popLast()
    }
}

public class UURemoteData: UURemoteDataProtocol, @unchecked Sendable
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

    private let downloadCoalescer = UUAsyncCoalescer<String, CoalescedDownloadResponse>()
    private let pendingQueue = UURemoteDataPendingQueue()

    private var httpRequestLookups: [String: [UUDataLoadedCompletionBlock]] = [:]
    private var httpRequestLookupsLock = NSRecursiveLock()
    
    // Default to 4 active requests at a time...
    public var maxActiveRequests: Int = 4
    
    public var networkTimeout: TimeInterval = UUHttpConfig.shared.defaultTimeout
    
    // Optional hook to provide an instance of UURemoteApi.  When set UURemoteData sends
    // requests through the remoteApi
    let remoteApi: UURemoteApi
    let dataCache: UUDataCache
    
    nonisolated(unsafe) static public let shared = UURemoteData(dataCache: UUDataCache.shared, remoteApi: UURemoteApi())
    
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

        appendRemoteHandler(for: key, handler: remoteLoadCompletion)

        Task
        {
            await beginDownloadIfNeeded(for: key)
        }

        return nil
    }

    public func isDownloadActive(for key: String) -> Bool
    {
        downloadCoalescer.isInFlightSync(key: key)
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

    private func beginDownloadIfNeeded(for key: String) async
    {
        if downloadCoalescer.isInFlightSync(key: key)
        {
            return
        }

        if downloadCoalescer.syncInFlightCount > maxActiveRequests
        {
            await pendingQueue.queuePending(for: key)
            return
        }

        await performCoalescedDownload(for: key)
    }

    private func performCoalescedDownload(for key: String) async
    {
        nonisolated(unsafe) let api = remoteApi
        let timeout = networkTimeout

        let coalesced = try? await downloadCoalescer.run(key: key)
        {
            let request = UUHttpRequest(url: key)
            request.responseHandler = UUPassthroughResponseHandler()
            request.timeout = timeout
            let response = await api.executeOneRequest(request)
            return CoalescedDownloadResponse(response: response)
        }

        if let coalesced
        {
            handleDownloadResponse(coalesced.response, key)
        }

        await checkForPendingRequests()
    }

    internal func executeRequest(_ request: UUHttpRequest, completion: @escaping (UUHttpResponse) -> Void)
    {
        nonisolated(unsafe) let api = remoteApi
        nonisolated(unsafe) let done = completion

        Task
        {
            let response = await api.executeOneRequest(request)
            done(response)
        }
    }

    private func checkForPendingRequests() async
    {
        while downloadCoalescer.syncInFlightCount < maxActiveRequests
        {
            guard let next = await pendingQueue.dequeuePending() else
            {
                break
            }

            await beginDownloadIfNeeded(for: next)
        }
    }

    private func handleDownloadResponse(_ response: UUHttpResponse, _ key: String)
    {
        let handlers = takeRemoteHandlers(for: key)

        var md: [String: Any] = [:]
        md[UURemoteData.NotificationKeys.RemotePath] = key

        if (response.httpError == nil && response.rawResponse != nil)
        {
            let responseData = response.rawResponse!

            dataCache.set(data: responseData, for: key)
            updateMetaDataFromResponse(response, for: key)
            notifyDataDownloaded(metaData: md)

            notifyRemoteDownloadHandlers(key: key, data: responseData, error: nil, handlers: handlers)
        }
        else
        {
            UULog.debug(tag: LOG_TAG, message: "Remote download failed!\n\nPath: \(key)\nStatusCode: \(String(describing: response.httpResponse?.statusCode))\nError: \(String(describing: response.httpError))\n")

            notifyDownloadFailed(key, response.httpError)
            notifyRemoteDownloadHandlers(key: key, data: nil, error: response.httpError, handlers: handlers)
        }
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
    
    private func notifyDownloadFailed(_ key: String, _ error: Error?)
    {
        DispatchQueue.global(qos: .userInitiated).async
        {
            var metaData: [String: Any] = [:]
            metaData[UURemoteData.NotificationKeys.RemotePath] = key
            metaData[NotificationKeys.Error] = error
            NotificationCenter.default.post(name: Notifications.DataDownloadFailed, object: nil, userInfo: metaData)
        }
    }
    
    private func notifyDataDownloaded(metaData: [String:Any])
    {
        let jsonData = metaData.uuToJson()
        DispatchQueue.global(qos: .userInitiated).async
        {
            let jsonObject = jsonData?.uuToJson() as? [String:Any]
            NotificationCenter.default.post(name: Notifications.DataDownloaded, object: nil, userInfo: jsonObject)
        }
    }
    
    private func notifyRemoteDownloadHandlers(key: String, data: Data?, error: Error?, handlers: [UUDataLoadedCompletionBlock])
    {
        for handler in handlers
        {
            handler(data, error)
        }
    }

    private func appendRemoteHandler(for key: String, handler: UUDataLoadedCompletionBlock?)
    {
        defer { httpRequestLookupsLock.unlock() }
        httpRequestLookupsLock.lock()

        if let remoteHandler = handler
        {
            var handlers = httpRequestLookups[key] ?? []
            handlers.append(remoteHandler)
            httpRequestLookups[key] = handlers
        }
    }

    private func takeRemoteHandlers(for key: String) -> [UUDataLoadedCompletionBlock]
    {
        defer { httpRequestLookupsLock.unlock() }
        httpRequestLookupsLock.lock()

        return httpRequestLookups.removeValue(forKey: key) ?? []
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
