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
//  Threading contract:
//  | API              | Returns on caller | Completion on     | Heavy work on              |
//  |------------------|-------------------|-------------------|----------------------------|
//  | data(for:)       | caller (await)    | callbackQueue     | cacheQueue + detached dl   |
//  | save(data:)      | caller (await)    | N/A               | cacheQueue                 |
//  | Notifications    | N/A               | notificationQueue | JSON prep on caller thread |

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UURemoteData"

public protocol UURemoteDataProtocol
{
    func data(for key: String) async -> Data?
    func isDownloadActive(for key: String) async -> Bool
    
    func metaData(for key: String) async -> [String:Any]
    func set(metaData: [String:Any], for key: String) async
}

public typealias UUDataLoadedCompletionBlock = @Sendable (Data?, Error?) async -> Void

private struct CoalescedDownloadResponse: @unchecked Sendable
{
    let response: UUHttpResponse
}

private struct UncheckedSendableBox<T>: @unchecked Sendable
{
    let value: T
    init(_ value: T) { self.value = value }
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
    private let memoryCache = NSCache<NSString, NSData>()

    private var httpRequestLookups: [String: [UUDataLoadedCompletionBlock]] = [:]
    private var httpRequestLookupsLock = NSRecursiveLock()
    
    // Default to 4 active requests at a time...
    public var maxActiveRequests: Int = 4
    
    public var networkTimeout: TimeInterval = UUHttpConfig.shared.defaultTimeout

    /// Serial queue for disk cache reads/writes initiated by UURemoteData.
    public var cacheQueue: DispatchQueue = DispatchQueue(
        label: "com.silverpine.uu.remoteData.cache",
        qos: .utility)

    /// Queue used to deliver `remoteLoadCompletion` handlers. Defaults to main.
    public var callbackQueue: DispatchQueue = .main

    /// Queue used to post download notifications. Defaults to main.
    public var notificationQueue: DispatchQueue = .main
    
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
    public func data(for key: String) async -> Data?
    {
        return await data(for: key, remoteLoadCompletion: nil)
    }
    
    public func data(for key: String, remoteLoadCompletion: UUDataLoadedCompletionBlock? = nil) async -> Data?
    {
        let url = URL(string: key)
        if (url == nil)
        {
            return nil
        }

        if let cached = memoryCache.object(forKey: key as NSString) as Data?
        {
            return cached
        }

        if await cacheDataExists(for: key)
        {
            let data = await cacheData(for: key)
            if let data
            {
                storeInMemoryCache(data, for: key)
                return data
            }
        }

        appendRemoteHandler(for: key, handler: remoteLoadCompletion)

        let instance = self
        Task.detached(priority: .utility)
        {
            await instance.beginDownloadIfNeeded(for: key)
        }

        return nil
    }

    public func isDownloadActive(for key: String) async -> Bool
    {
        downloadCoalescer.isInFlightSync(key: key)
    }
    
    public func metaData(for key: String) async -> [String:Any]
    {
        await performOnCacheQueue
        {
            await self.dataCache.metaData(for: key)
        }
    }
    
    public func set(metaData: [String:Any], for key: String) async
    {
        let mdBox = UncheckedSendableBox(metaData)
        let cacheKey = key
        await performOnCacheQueue
        {
            await self.dataCache.set(metaData: mdBox.value, for: cacheKey)
        }
    }

    /// Returns true when data is present in the memory hot cache or on disk, without starting a download.
    public func cachedDataExists(for key: String) async -> Bool
    {
        if memoryCache.object(forKey: key as NSString) != nil
        {
            return true
        }

        return await cacheDataExists(for: key)
    }

    /// Clears the in-memory hot cache. Does not affect disk cache.
    public func clearMemoryCache()
    {
        memoryCache.removeAllObjects()
    }

    ////////////////////////////////////////////////////////////////////////////
    // Private Implementation
    ////////////////////////////////////////////////////////////////////////////

    private func cacheDataExists(for key: String) async -> Bool
    {
        await performOnCacheQueue
        {
            await self.dataCache.dataExists(for: key)
        }
    }

    private func cacheData(for key: String) async -> Data?
    {
        await performOnCacheQueue
        {
            await self.dataCache.data(for: key)
        }
    }

    private func cacheSet(data: Data, for key: String) async
    {
        await performOnCacheQueue
        {
            await self.dataCache.set(data: data, for: key)
        }
        storeInMemoryCache(data, for: key)
    }

    private func performOnCacheQueue<T>(
        _ operation: @Sendable @escaping () async -> T) async -> T
    {
        let queue = cacheQueue
        return await withCheckedContinuation
        { continuation in
            queue.async
            {
                Task
                {
                    let result = await operation()
                    continuation.resume(returning: result)
                }
            }
        }
    }

    private func storeInMemoryCache(_ data: Data, for key: String)
    {
        memoryCache.setObject(data as NSData, forKey: key as NSString)
    }

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
            let response = await api.executeRequest(request)
            return CoalescedDownloadResponse(response: response)
        }

        if let coalesced
        {
            await handleDownloadResponse(coalesced.response, key)
        }

        await checkForPendingRequests()
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

    private func handleDownloadResponse(_ response: UUHttpResponse, _ key: String) async
    {
        let handlers = takeRemoteHandlers(for: key)

        var md: [String: Any] = [:]
        md[UURemoteData.NotificationKeys.RemotePath] = key

        if (response.httpError == nil && response.rawResponse != nil)
        {
            let responseData = response.rawResponse!

            await cacheSet(data: responseData, for: key)
            await updateMetaDataFromResponse(response, for: key)
            notifyDataDownloaded(metaData: md)

            await notifyRemoteDownloadHandlers(key: key, data: responseData, error: nil, handlers: handlers)
        }
        else
        {
            UULog.debug(tag: LOG_TAG, message: "Remote download failed!\n\nPath: \(key)\nStatusCode: \(String(describing: response.httpResponse?.statusCode))\nError: \(String(describing: response.httpError))\n")

            notifyDownloadFailed(key, response.httpError)
            await notifyRemoteDownloadHandlers(key: key, data: nil, error: response.httpError, handlers: handlers)
        }
    }
    
    private func updateMetaDataFromResponse(_ response: UUHttpResponse, for key: String) async
    {
        let mimeType = response.httpResponse?.mimeType ?? ""
        let cacheKey = key
        await performOnCacheQueue
        {
            var md = await self.dataCache.metaData(for: cacheKey)
            md[MetaData.MimeType] = mimeType
            md[MetaData.DownloadTimestamp] = Date()
            await self.dataCache.set(metaData: md, for: cacheKey)
        }
    }
    
    public func save(data: Data, key: String) async
    {
        await cacheSet(data: data, for: key)
        
        let cacheKey = key
        await performOnCacheQueue
        {
            var md = await self.dataCache.metaData(for: cacheKey)
            md[MetaData.MimeType] = "raw"
            md[MetaData.DownloadTimestamp] = Date()
            md[UURemoteData.NotificationKeys.RemotePath] = cacheKey
            await self.dataCache.set(metaData: md, for: cacheKey)
        }
        
        var notifyMd: [String: Any] = [:]
        notifyMd[UURemoteData.NotificationKeys.RemotePath] = key
        notifyDataDownloaded(metaData: notifyMd)
    }
    
    private func notifyDownloadFailed(_ key: String, _ error: Error?)
    {
        let queue = notificationQueue
        queue.async
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
        let queue = notificationQueue
        queue.async
        {
            let jsonObject = jsonData?.uuToJson() as? [String:Any]
            NotificationCenter.default.post(name: Notifications.DataDownloaded, object: nil, userInfo: jsonObject)
        }
    }
    
    private func notifyRemoteDownloadHandlers(key: String, data: Data?, error: Error?, handlers: [UUDataLoadedCompletionBlock]) async
    {
        let queue = callbackQueue
        for handler in handlers
        {
            await withCheckedContinuation
            { (continuation: CheckedContinuation<Void, Never>) in
                queue.async
                {
                    Task
                    {
                        await handler(data, error)
                        continuation.resume()
                    }
                }
            }
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
