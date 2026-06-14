//
//  UURemoteObject.swift
//  UUSwiftNetworking
//
//  A generic, from-scratch remote object loader with layered caching and
//  single-flight network coalescing.
//
//  License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//
//  Responsibilities:
//
//  1. Resolve a typed value for a URL from, in order, a memory cache (typed),
//     a disk cache (raw bytes), then the network (raw bytes).
//  2. Decode raw bytes into the typed value, persisting the bytes (and any
//     derived metadata) to disk and the decoded value to memory.
//  3. Coalesce concurrent requests for the same URL into a single network
//     transfer + decode that every caller awaits.
//  4. Honor cooperative cancellation: cancelling the awaiting task stops the
//     caller from waiting (mirrors the UUHttpSession cancellation model).
//
//  All network and disk work runs in async contexts off of the main thread.
//
//  Dependencies:
//
//  - UURemoteObjectApi  (network + authorization lifecycle)
//  - UUDataCache        (disk persistence + metadata)
//  - UUAsyncCoalescer   (single-flight network coalescing)
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UURemoteObject"

/// A `Sendable` reference box used to carry a (possibly non-`Sendable`) value across task
/// boundaries and to store it in an `NSCache`.
///
/// The wrapped value is immutable, so sharing the box across concurrency domains is safe even when
/// `Value` itself (for example `UIImage`) does not conform to `Sendable`.
nonisolated public final class UUObjectBox<Value>: @unchecked Sendable
{
    /// The wrapped value.
    public let value: Value

    /// Wraps a value for cross-actor transport and cache storage.
    public init(_ value: Value)
    {
        self.value = value
    }
}

/// Errors surfaced by ``UURemoteObject`` in addition to any underlying HTTP or network error.
public enum UURemoteObjectError: Error, Sendable
{
    /// The supplied key could not be interpreted as a URL.
    case invalidUrl(String)

    /// The network transfer succeeded but returned no body to cache.
    case emptyResponse(String)

    /// The downloaded bytes could not be decoded into the requested value type.
    case decodeFailed(String)
}

extension UURemoteObjectError: LocalizedError
{
    public var errorDescription: String?
    {
        switch self
        {
            case .invalidUrl(let url):
                return "The string '\(url)' is not a valid URL."

            case .emptyResponse(let url):
                return "The request for '\(url)' returned an empty response."

            case .decodeFailed(let url):
                return "The data for '\(url)' could not be decoded into the requested type."
        }
    }
}

/// A generic remote loader with a typed memory cache, a raw-bytes disk cache, and single-flight
/// network coalescing.
///
/// `UURemoteObject` resolves a value for a URL using a three-tier lookup:
///
/// 1. A typed in-memory hot cache (`NSCache` of ``UUObjectBox`` of `Value`).
/// 2. A persistent disk cache of raw bytes (``UUDataCache``).
/// 3. A coalesced network download through ``UURemoteObjectApi``.
///
/// Network and disk layers always operate on `Data`. The generic `Value` is produced by
/// ``decode(_:for:)`` and is the only representation held in memory. For a raw-bytes loader,
/// `Value` is `Data` and decoding is an identity cast (see ``UURemoteDataV2``). For an image loader,
/// `Value` is `UUImage` and decoding builds and prepares the image (see ``UURemoteImageV2``).
///
/// ## Coalescing
///
/// When several callers request the same URL while a download is in flight, only one network
/// transfer + decode runs. Every caller awaits that shared work and receives the same result.
///
/// ## Cancellation
///
/// Cancellation is cooperative and follows the ``UUHttpSession`` model: a caller cancels by
/// cancelling the task awaiting ``object(for:)``. The call throws `CancellationError`. Because the
/// shared download is insulated from any individual caller's task, cancelling one waiter does not
/// disturb the download for the remaining waiters.
///
/// ## Threading
///
/// All network and disk-cache work runs in async contexts on the cooperative thread pool, never on
/// the main thread. The memory cache is backed by a thread-safe `NSCache`.
///
/// ## Extensibility
///
/// Override these pipeline stages to specialize behavior:
///
/// - ``transform(downloadedData:for:)`` — post-process raw bytes before they are cached to disk.
/// - ``decode(_:for:)`` — convert raw bytes into the typed `Value` held in memory.
/// - ``cost(for:)`` — report the memory cost of a decoded value for `NSCache` accounting.
/// - ``additionalMetadata(for:data:url:)`` — derive extra metadata to persist alongside the bytes.
open class UURemoteObject<Value>: @unchecked Sendable
{
    /// The API client used to perform downloads, including its authorization lifecycle.
    public let remoteApi: UURemoteObjectApi

    /// The disk cache backing store for downloaded raw bytes and metadata.
    nonisolated(unsafe) public let dataCache: UUDataCacheProtocol

    private let memoryCache = NSCache<NSString, UUObjectBox<Value>>()
    private let coalescer = UUAsyncCoalescer<String, UUObjectBox<Value>>()

    /// The maximum total cost the in-memory cache will hold before evicting entries.
    ///
    /// Maps directly to `NSCache.totalCostLimit`. A value of `0` (the default) means no limit. The
    /// cost of each entry is reported by ``cost(for:)``.
    public var memoryCostLimit: Int
    {
        get { memoryCache.totalCostLimit }
        set { memoryCache.totalCostLimit = newValue }
    }

    /// Creates a remote object loader.
    ///
    /// - Parameters:
    ///   - dataCache: The disk cache used for byte and metadata persistence.
    ///   - remoteApi: The API client used for network requests. Inject a subclass to add
    ///     authorization, custom sessions, or a bespoke response handler.
    public init(
        dataCache: UUDataCacheProtocol,
        remoteApi: UURemoteObjectApi)
    {
        self.dataCache = dataCache
        self.remoteApi = remoteApi
    }

    // MARK: - Public API

    /// Returns the typed value for a URL from the memory cache, disk cache, or network.
    ///
    /// - Parameter url: The remote URL string, also used as the cache key.
    /// - Returns: The resolved, decoded value.
    /// - Throws: ``UURemoteObjectError`` for invalid input, empty responses, or decode failures;
    ///   the underlying HTTP or network error on failure; or `CancellationError` if the awaiting
    ///   task is cancelled.
    open func object(for url: String) async throws -> Value
    {
        try Task.checkCancellation()

        guard URL(string: url) != nil else
        {
            throw UURemoteObjectError.invalidUrl(url)
        }

        if let memoryCached = memoryCachedObject(for: url)
        {
            return memoryCached
        }

        if let diskData = await diskCachedData(for: url)
        {
            let decoded = try await decode(diskData, for: url)
            storeInMemoryCache(decoded, for: url)
            return decoded
        }

        try Task.checkCancellation()

        let boxed = try await coalescedDownload(for: url)

        try Task.checkCancellation()
        return boxed.value
    }

    // MARK: - Cache Access

    /// Returns the decoded value already present in the memory cache, if any.
    public func memoryCachedObject(for url: String) -> Value?
    {
        memoryCache.object(forKey: url as NSString)?.value
    }

    /// Returns the raw bytes already present in the disk cache, if any. Runs off the main thread.
    open func diskCachedData(for url: String) async -> Data?
    {
        await dataCache.data(for: url)
    }

    /// Removes all entries from the in-memory hot cache. Does not affect the disk cache.
    public func clearMemoryCache()
    {
        memoryCache.removeAllObjects()
    }

    // MARK: - Pipeline (overridable)

    /// Post-processes freshly downloaded bytes before they are cached to disk.
    ///
    /// The default implementation returns the data unchanged. Override to validate, normalize, or
    /// re-encode the payload. Runs once per download on the worker performing the coalesced
    /// transfer.
    ///
    /// - Parameters:
    ///   - data: The raw downloaded bytes.
    ///   - url: The URL the bytes were downloaded from.
    /// - Returns: The bytes to cache to disk and decode.
    open func transform(downloadedData data: Data, for url: String) async throws -> Data
    {
        return data
    }

    /// Converts raw bytes into the typed value held in the memory cache.
    ///
    /// The default implementation performs an identity cast, which succeeds only when `Value` is
    /// `Data`. Subclasses with a non-`Data` value type must override this.
    ///
    /// Runs once per download on the coalesced worker, and once per disk-cache hit.
    ///
    /// - Parameters:
    ///   - data: The (possibly transformed) bytes to decode.
    ///   - url: The URL the bytes belong to.
    /// - Returns: The decoded value.
    /// - Throws: ``UURemoteObjectError/decodeFailed(_:)`` when the bytes cannot be decoded.
    open func decode(_ data: Data, for url: String) async throws -> Value
    {
        guard let value = data as? Value else
        {
            throw UURemoteObjectError.decodeFailed(url)
        }

        return value
    }

    /// Reports the memory cost of a decoded value for `NSCache` accounting against
    /// ``memoryCostLimit``.
    ///
    /// The default returns the byte count when `Value` is `Data`, otherwise `0`. Override to supply
    /// an accurate cost for other value types (for example decoded image byte size).
    open func cost(for value: Value) -> Int
    {
        (value as? Data)?.count ?? 0
    }

    /// Derives additional metadata to persist alongside the cached bytes.
    ///
    /// The default returns an empty dictionary. Override to store derived attributes (for example
    /// image dimensions). Returned keys are merged into any existing disk-cache metadata for the
    /// URL. Runs once per download on the coalesced worker.
    ///
    /// - Parameters:
    ///   - value: The decoded value.
    ///   - data: The bytes that were cached to disk.
    ///   - url: The URL the bytes belong to.
    /// - Returns: Metadata to merge into the disk cache, or an empty dictionary for none.
    open func additionalMetadata(for value: Value, data: Data, url: String) async -> [String: Any]
    {
        [:]
    }

    // MARK: - Private Implementation

    private func coalescedDownload(for url: String) async throws -> UUObjectBox<Value>
    {
        // The coalescer's operation is `@Sendable` (nonisolated), so the entire pipeline runs in a
        // single isolated method and only the `Sendable` ``UUObjectBox`` crosses the boundary. The
        // decoded value (which may be non-`Sendable`, e.g. an image) never leaves this object's
        // isolation domain until it is boxed.
        try await coalescer.run(key: url)
        {
            try Task.checkCancellation()
            return try await self.runDownloadPipeline(for: url)
        }
    }

    private func runDownloadPipeline(for url: String) async throws -> UUObjectBox<Value>
    {
        let raw = try await performDownload(for: url)
        let processed = try await transform(downloadedData: raw, for: url)
        let decoded = try await decode(processed, for: url)

        // Persist once, by the single coalesced worker, before any waiter returns.
        await persist(data: processed, value: decoded, for: url)

        return UUObjectBox(decoded)
    }

    private func performDownload(for url: String) async throws -> Data
    {
        let request = UUHttpRequest(url: url)
        let response = await remoteApi.executeRequest(request)

        if let error = response.httpError
        {
            UULog.debug(tag: LOG_TAG, message: "Download failed\n\nURL: \(url)\nStatus: \(response.httpStatusCode)\nError: \(error)")
            throw error
        }

        guard let data = (response.parsedResponse as? Data) ?? response.rawResponse, !data.isEmpty else
        {
            throw UURemoteObjectError.emptyResponse(url)
        }

        return data
    }

    private func persist(data: Data, value: Value, for url: String) async
    {
        await dataCache.set(data: data, for: url)

        let extra = await additionalMetadata(for: value, data: data, url: url)
        if !extra.isEmpty
        {
            var metaData = await dataCache.metaData(for: url)
            for (key, item) in extra
            {
                metaData[key] = item
            }
            
            await dataCache.set(metaData: metaData, for: url)
        }

        storeInMemoryCache(value, for: url)
    }

    private func storeInMemoryCache(_ value: Value, for url: String)
    {
        memoryCache.setObject(UUObjectBox(value), forKey: url as NSString, cost: cost(for: value))
    }
}

/// Parses remote download bodies as raw ``Data``.
///
/// ``UURemoteObject`` orchestrates all decoding and caching after the response is parsed and
/// cancellation has been checked, so this handler is intentionally a thin binary passthrough.
/// Subclass to customize parsing and override ``UURemoteObjectApi/makeResponseHandler()`` to
/// install it.
open class UURemoteObjectResponseHandler: UUPassthroughResponseHandler
{
    /// Creates a passthrough binary response handler.
    public override init()
    {
        super.init()
    }
}

/// A ``UURemoteApi`` subclass that attaches a binary passthrough response handler to each download.
///
/// Subclass to add authorization, custom sessions, or alternate parsing for downloads.
open class UURemoteObjectApi: UURemoteApi
{
    /// Returns the response handler installed on each download request.
    ///
    /// Override to supply a custom handler (for example, to validate or pre-process payloads).
    open func makeResponseHandler() -> UUHttpResponseHandler
    {
        UURemoteObjectResponseHandler()
    }

    open override func prepareRequest(_ request: UUHttpRequest) async
    {
        await super.prepareRequest(request)
        request.responseHandler = makeResponseHandler()
    }
}
