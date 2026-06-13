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

/// A protocol describing the remote data cache and download surface.
///
/// Implemented by ``UURemoteData``. Use the protocol when injecting a test double or
/// alternate implementation.
public protocol UURemoteDataProtocol
{
    /// Returns cached or freshly downloaded data for a remote URL key.
    func data(for key: String) async -> Data?

    /// Returns whether a network download is currently in flight for the key.
    func isDownloadActive(for key: String) async -> Bool

    /// Returns persisted metadata for a cache key.
    func metaData(for key: String) async -> [String:Any]

    /// Persists metadata for a cache key.
    func set(metaData: [String:Any], for key: String) async

    /// Cancels a pending or in-flight download for the key.
    func cancelDownload(for key: String)
}

/// An async completion handler invoked when a remote download finishes.
///
/// Called on ``UURemoteData/callbackQueue`` after the download succeeds or fails.
/// Handlers are `@Sendable` and safe to capture across concurrency domains.
///
/// - Parameters:
///   - data: The downloaded bytes, or `nil` on failure or cancellation.
///   - error: The HTTP or network error, or `nil` on success.
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

private struct PendingDownload: Sendable
{
    let key: String
    let requestGeneration: UInt64
}

private actor UURemoteDataPendingQueue
{
    private var pendingDownloads: [PendingDownload] = []

    func queuePending(for key: String, generation: UInt64)
    {
        pendingDownloads.removeAll { $0.key == key }
        pendingDownloads.insert(PendingDownload(key: key, requestGeneration: generation), at: 0)
    }

    func dequeuePending() -> PendingDownload?
    {
        pendingDownloads.popLast()
    }

    func removePending(for key: String)
    {
        pendingDownloads.removeAll { $0.key == key }
    }
}

/// A centralized remote data loader with memory and disk caching, download coalescing, and throttling.
///
/// `UURemoteData` is the recommended entry point for fetching binary content from URLs. Callers pass
/// a URL string as the cache key. The type consults an in-memory hot cache, then ``UUDataCache`` on
/// disk, and only then starts a coalesced network download through ``UURemoteApi``.
///
/// Multiple concurrent requests for the same key share one network transfer. Downloads are throttled
/// by ``maxActiveRequests``; additional keys wait in a pending queue until a slot opens.
///
/// ## Cancellation
///
/// ``cancelDownload(for:)`` invalidates the current download generation for a key, drops registered
/// completion handlers without calling them, removes the key from the pending queue, and cancels any
/// in-flight coalesced task. A subsequent ``data(for:remoteLoadCompletion:)`` starts fresh work.
///
/// ## Threading
///
/// | API | Returns on | Completion / notifications | Heavy work |
/// |-----|------------|------------------------------|------------|
/// | ``data(for:)`` | Caller (await) | ``callbackQueue`` | ``cacheQueue`` + detached download |
/// | ``save(data:key:)`` | Caller (await) | N/A | ``cacheQueue`` |
/// | Notifications | N/A | ``notificationQueue`` | JSON prep on caller thread |
///
/// ## Dependencies
///
/// - ``UUHttpSession`` (via ``UURemoteApi``)
/// - ``UUDataCache``
public class UURemoteData: UURemoteDataProtocol, @unchecked Sendable
{
    /// Notification names posted when remote data events occur.
    public struct Notifications
    {
        /// Posted when data is successfully downloaded and cached.
        ///
        /// The `userInfo` dictionary contains ``NotificationKeys/RemotePath``.
        public static let DataDownloaded = Notification.Name("UUDataDownloadedNotification")

        /// Posted when a remote download fails.
        ///
        /// The `userInfo` dictionary contains ``NotificationKeys/RemotePath`` and
        /// ``NotificationKeys/Error``.
        public static let DataDownloadFailed = Notification.Name("UUDataDownloadFailedNotification")
    }

    /// Keys used in cache metadata and download notifications.
    public struct MetaData
    {
        /// The MIME type reported by the HTTP response.
        public static let MimeType = "MimeType"

        /// The date the content was downloaded or saved.
        public static let DownloadTimestamp = "DownloadTimestamp"
    }

    /// Keys available in notification `userInfo` dictionaries.
    public struct NotificationKeys
    {
        /// The remote URL path (cache key) associated with the event.
        public static let RemotePath = "UUDataRemotePathKey"

        /// The error that caused a download failure.
        public static let Error = "UURemoteDataErrorKey"
    }

    private let downloadCoalescer = UUAsyncCoalescer<String, CoalescedDownloadResponse>()
    private let pendingQueue = UURemoteDataPendingQueue()
    private let memoryCache = NSCache<NSString, NSData>()

    private var httpRequestLookups: [String: [UUDataLoadedCompletionBlock]] = [:]
    private var httpRequestLookupsLock = NSRecursiveLock()

    private var downloadGeneration: [String: UInt64] = [:]
    private var downloadStartedGeneration: [String: UInt64] = [:]
    private var downloadGenerationLock = NSLock()
    
    /// The maximum number of concurrent in-flight downloads before additional keys are queued.
    ///
    /// Defaults to `4`. When the number of active coalesced downloads exceeds this value, further
    /// keys are held in an internal pending queue until a slot becomes available.
    public var maxActiveRequests: Int = 4

    /// The timeout applied to each download ``UUHttpRequest``.
    ///
    /// Defaults to ``UUHttpConfig/shared`` `defaultTimeout`.
    public var networkTimeout: TimeInterval = UUHttpConfig.shared.defaultTimeout

    /// Serial queue for disk cache reads and writes initiated by this instance.
    public var cacheQueue: DispatchQueue = DispatchQueue(
        label: "com.silverpine.uu.remoteData.cache",
        qos: .utility)

    /// Queue used to deliver ``UUDataLoadedCompletionBlock`` handlers. Defaults to the main queue.
    public var callbackQueue: DispatchQueue = .main

    /// Queue used to post ``Notifications`` events. Defaults to the main queue.
    public var notificationQueue: DispatchQueue = .main

    /// The API client used to perform authorized HTTP downloads.
    let remoteApi: UURemoteApi

    /// The disk cache backing store for downloaded data.
    let dataCache: UUDataCache

    /// The shared remote data instance using ``UUDataCache/shared`` and a default ``UURemoteApi``.
    static public let shared = UURemoteData(dataCache: UUDataCache.shared, remoteApi: UURemoteApi())

    /// Creates a remote data loader with the given cache and API client.
    ///
    /// - Parameters:
    ///   - dataCache: The disk cache used for persistence.
    ///   - remoteApi: The API client used for network requests. Inject a subclass to add
    ///     authorization or custom session configuration.
    required init(dataCache: UUDataCache, remoteApi: UURemoteApi)
    {
        self.dataCache = dataCache
        self.remoteApi = remoteApi
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // UURemoteDataProtocol Implementation
    ////////////////////////////////////////////////////////////////////////////
    /// Returns cached or downloaded data for a remote URL.
    ///
    /// The `key` must be a string that ``URL/init(string:)`` accepts. Lookup order is memory hot
    /// cache, disk cache, then network. When data is not immediately available, `nil` is returned
    /// and a background download is started.
    ///
    /// - Parameter key: The remote URL string used as the cache key.
    /// - Returns: Cached data when available synchronously from memory or disk, otherwise `nil`
    ///   while a download is in progress.
    public func data(for key: String) async -> Data?
    {
        return await data(for: key, remoteLoadCompletion: nil)
    }

    /// Returns cached or downloaded data for a remote URL, invoking a completion when a background
    /// download finishes.
    ///
    /// When data is already in the memory or disk cache, it is returned immediately and the
    /// completion is not called. When a download is required, this method returns `nil` and the
    /// completion is invoked on ``callbackQueue`` when the transfer completes, fails, or is
    /// cancelled via ``cancelDownload(for:)``.
    ///
    /// - Parameters:
    ///   - key: The remote URL string used as the cache key.
    ///   - remoteLoadCompletion: An optional handler invoked when a background download completes.
    ///     Ignored when data is returned synchronously from cache.
    /// - Returns: Cached data when immediately available, otherwise `nil`.
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

        let requestGeneration = currentDownloadGeneration(for: key)
        let instance = self
        Task.detached(priority: .utility)
        {
            await instance.beginDownloadIfNeeded(for: key, requestGeneration: requestGeneration)
        }

        return nil
    }

    /// Returns whether a coalesced network download is currently in flight for the key.
    ///
    /// Pending downloads waiting for an available slot in ``maxActiveRequests`` return `false`.
    ///
    /// - Parameter key: The remote URL string used as the cache key.
    /// - Returns: `true` when an active download task exists for the key.
    public func isDownloadActive(for key: String) async -> Bool
    {
        downloadCoalescer.isInFlightSync(key: key)
    }
    
    /// Returns persisted metadata for a cache key.
    ///
    /// - Parameter key: The cache key, typically a remote URL string.
    /// - Returns: The metadata dictionary stored in ``dataCache``.
    public func metaData(for key: String) async -> [String:Any]
    {
        await performOnCacheQueue
        {
            await self.dataCache.metaData(for: key)
        }
    }
    
    /// Persists metadata for a cache key.
    ///
    /// - Parameters:
    ///   - metaData: The metadata dictionary to store.
    ///   - key: The cache key, typically a remote URL string.
    public func set(metaData: [String:Any], for key: String) async
    {
        let mdBox = UncheckedSendableBox(metaData)
        let cacheKey = key
        await performOnCacheQueue
        {
            await self.dataCache.set(metaData: mdBox.value, for: cacheKey)
        }
    }
    
    /// Cancels a pending or in-flight download for the key.
    ///
    /// This method returns immediately. It bumps the internal download generation so detached and
    /// queued work for the key is ignored, removes any registered ``UUDataLoadedCompletionBlock``
    /// handlers without invoking them, dequeuing the key from the pending queue when applicable,
    /// and cancels the coalesced in-flight task when one exists.
    ///
    /// Does not remove data already present in the memory or disk cache. A later call to
    /// ``data(for:)`` starts a new download attempt.
    ///
    /// - Parameter key: The remote URL string used as the cache key.
    public func cancelDownload(for key: String)
    {
        invalidateDownload(for: key)
        _ = takeRemoteHandlers(for: key)

        let instance = self
        Task.detached(priority: .utility)
        {
            await instance.pendingQueue.removePending(for: key)
            await instance.downloadCoalescer.cancel(key: key)
        }
    }

    /// Returns whether data exists in the memory hot cache or on disk without starting a download.
    ///
    /// - Parameter key: The remote URL string used as the cache key.
    /// - Returns: `true` when cached data is available locally.
    public func cachedDataExists(for key: String) async -> Bool
    {
        if memoryCache.object(forKey: key as NSString) != nil
        {
            return true
        }

        return await cacheDataExists(for: key)
    }

    /// Clears the in-memory hot cache.
    ///
    /// Does not remove data from ``dataCache`` on disk.
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

    private func beginDownloadIfNeeded(for key: String, requestGeneration: UInt64) async
    {
        if !isDownloadStillValid(for: key, requestGeneration: requestGeneration)
        {
            return
        }

        if downloadCoalescer.isInFlightSync(key: key)
        {
            return
        }

        if downloadCoalescer.syncInFlightCount > maxActiveRequests
        {
            await pendingQueue.queuePending(for: key, generation: requestGeneration)
            return
        }

        await performCoalescedDownload(for: key, requestGeneration: requestGeneration)
    }

    private func performCoalescedDownload(for key: String, requestGeneration: UInt64) async
    {
        if !isDownloadStillValid(for: key, requestGeneration: requestGeneration)
        {
            return
        }

        recordDownloadStarted(for: key, requestGeneration: requestGeneration)
        defer { clearDownloadStarted(for: key) }

        nonisolated(unsafe) let api = remoteApi
        let timeout = networkTimeout

        let coalesced = try? await downloadCoalescer.run(key: key)
        {
            if Task.isCancelled
            {
                throw CancellationError()
            }

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
        while downloadCoalescer.syncInFlightCount <= maxActiveRequests
        {
            guard let next = await pendingQueue.dequeuePending() else
            {
                break
            }

            await beginDownloadIfNeeded(for: next.key, requestGeneration: next.requestGeneration)
        }
    }

    private func handleDownloadResponse(_ response: UUHttpResponse, _ key: String) async
    {
        if isDownloadCancelled(for: key)
        {
            return
        }

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
    
    /// Writes data to the memory and disk cache and posts ``Notifications/DataDownloaded``.
    ///
    /// Use this to seed the cache without a network request. Metadata is updated with MIME type
    /// `"raw"` and a download timestamp.
    ///
    /// - Parameters:
    ///   - data: The bytes to store.
    ///   - key: The cache key, typically a remote URL string.
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

    private func isDownloadCancelled(for key: String) -> Bool
    {
        downloadGenerationLock.lock()
        defer { downloadGenerationLock.unlock() }

        guard let startedGeneration = downloadStartedGeneration[key] else
        {
            return false
        }

        return (downloadGeneration[key] ?? 0) != startedGeneration
    }

    private func currentDownloadGeneration(for key: String) -> UInt64
    {
        downloadGenerationLock.lock()
        defer { downloadGenerationLock.unlock() }
        return downloadGeneration[key] ?? 0
    }

    private func invalidateDownload(for key: String)
    {
        downloadGenerationLock.lock()
        downloadGeneration[key] = (downloadGeneration[key] ?? 0) + 1
        downloadGenerationLock.unlock()
    }

    private func isDownloadStillValid(for key: String, requestGeneration: UInt64) -> Bool
    {
        downloadGenerationLock.lock()
        defer { downloadGenerationLock.unlock() }
        return (downloadGeneration[key] ?? 0) == requestGeneration
    }

    private func recordDownloadStarted(for key: String, requestGeneration: UInt64)
    {
        downloadGenerationLock.lock()
        downloadStartedGeneration[key] = requestGeneration
        downloadGenerationLock.unlock()
    }

    private func clearDownloadStarted(for key: String)
    {
        downloadGenerationLock.lock()
        downloadStartedGeneration.removeValue(forKey: key)
        downloadGenerationLock.unlock()
    }
}

extension Notification
{
    /// The remote path (cache key) from a ``UURemoteData`` notification, if present.
    public var uuRemoteDataPath : String?
    {
        return userInfo?[UURemoteData.NotificationKeys.RemotePath] as? String
    }

    /// The error from a ``UURemoteData/Notifications/DataDownloadFailed`` notification, if present.
    public var uuRemoteDataError : Error?
    {
        return userInfo?[UURemoteData.NotificationKeys.Error] as? Error
    }
}
