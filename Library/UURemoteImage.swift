//
//  UURemoteImage.swift
//  Useful Utilities - An extension to Useful Utilities
//  UURemoteData that exposes the cached data as UIImage/NSImage objects
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//
//  NOTE: This class depends on the following toolbox classes:
//
//  UUHttpSession
//  UUDataCache
//  UURemoteData
//
#if os(macOS)
	import AppKit
	public typealias UUImage = NSImage
#else
	import UIKit
	public typealias UUImage = UIImage
#endif

import UUSwiftCore

/// A completion handler invoked when a remote image download and decode finishes.
///
/// Called on ``UURemoteImage/imageCallbackQueue``. The handler is `@Sendable`; hop to
/// `@MainActor` inside when updating UI state.
///
/// - Parameters:
///   - image: The decoded image, or `nil` on failure or cancellation.
///   - error: The underlying data download error, or `nil` on success.
public typealias UUImageLoadedCompletionBlock = @Sendable (UUImage?, Error?) -> Void

/// A remote image loader built on ``UURemoteData`` with decode caching and display preparation.
///
/// `UURemoteImage` fetches image bytes through ``UURemoteData``, decodes them off the caller
/// thread on ``imageDecodeQueue``, and stores decoded ``UUImage`` instances in an internal
/// memory cache. On iOS, decoded images are passed through `byPreparingForDisplay()` before
/// caching to reduce main-thread work during rendering.
///
/// ## Cache layers
///
/// 1. **Image memory cache** — decoded ``UUImage`` objects (this class).
/// 2. **Data memory / disk cache** — raw bytes (``UURemoteData`` / ``UUDataCache``).
///
/// When ``useDiskCache`` is `true`, image dimensions are persisted in remote data metadata after
/// decode. When `false`, only the in-memory image cache is used for presence checks.
///
/// ## Cancellation
///
/// Call ``UURemoteData/cancelDownload(for:)`` on the underlying ``UURemoteData`` instance to
/// cancel an in-flight download for a URL. Pair with SwiftUI `.task` cancellation and guards
/// before updating UI.
///
/// ## Threading
///
/// | Stage | Queue |
/// |-------|-------|
/// | Data fetch | ``UURemoteData`` (`cacheQueue`, detached download) |
/// | Image decode | ``imageDecodeQueue`` |
/// | Image completion | ``imageCallbackQueue`` (default main) |
/// | Notifications | ``imageNotificationQueue`` (default main) |
public class UURemoteImage: @unchecked Sendable
{
    /// The shared image loader using ``UURemoteData/shared``.
    public static let shared = UURemoteImage(remoteData: UURemoteData.shared)

    /// When `true`, disk cache and metadata from ``UURemoteData`` participate in cache lookups
    /// and dimension storage. When `false`, only the in-memory image cache is consulted.
    nonisolated(unsafe) public static var useDiskCache = true

    private let remoteData: UURemoteData

    /// Serial queue used for image decode and display preparation. Defaults to utility QoS.
    public var imageDecodeQueue: DispatchQueue = DispatchQueue(
        label: "com.silverpine.uu.remoteImage.decode",
        qos: .utility)

    /// Queue used to deliver ``UUImageLoadedCompletionBlock`` handlers. Defaults to the main queue.
    public var imageCallbackQueue: DispatchQueue = .main

    /// Queue used to post ``Notifications/ImageDownloaded``. Defaults to the main queue.
    public var imageNotificationQueue: DispatchQueue = .main

    /// Creates an image loader that fetches bytes through the given ``UURemoteData`` instance.
    ///
    /// - Parameter remoteData: The remote data loader used for byte fetching and disk caching.
    required init(remoteData: UURemoteData)
    {
        self.remoteData = remoteData
    }

    /// Notification names posted when image events occur.
    public struct Notifications
    {
        /// Posted when an image is successfully decoded and cached.
        ///
        /// The `userInfo` dictionary contains ``UURemoteData/NotificationKeys/RemotePath``.
        public static let ImageDownloaded = Notification.Name("UUImageDownloadedNotification")
    }

    /// Returns the cached pixel dimensions for a remote image path, when available.
    ///
    /// Dimensions are read from ``UURemoteData`` metadata populated during decode when
    /// ``useDiskCache`` is `true`.
    ///
    /// - Parameter path: The remote URL string used as the cache key.
    /// - Returns: The cached size, or `nil` when dimensions have not been stored.
    public func imageSize(for path: String) async -> CGSize?
    {
        if UURemoteImage.useDiskCache
        {
            let md = await remoteData.metaData(for: path)

            if let w = md[MetaData.ImageWidth] as? NSNumber,
               let h = md[MetaData.ImageHeight] as? NSNumber
            {
                return CGSize(width: CGFloat(w.floatValue), height: CGFloat(h.floatValue))
            }
        }

        return nil
    }

    /// Returns the internal decoded-image memory cache.
    ///
    /// Prefer ``clearCache()`` to evict all decoded images. Direct mutation affects all callers
    /// sharing this instance.
    public func memoryCache() -> NSCache<NSString, UUImage>
    {
        return self.systemImageCache
    }

    /// Removes all decoded images from the in-memory image cache.
    ///
    /// Does not clear raw bytes in ``UURemoteData``. Call ``UURemoteData/clearMemoryCache()``
    /// or ``UUDataCache/clearCache()`` to evict underlying data.
    public func clearCache()
    {
        self.systemImageCache.removeAllObjects()
    }

    /// Returns whether a decoded image or cached raw data exists for the key.
    ///
    /// Checks the in-memory image cache first. When ``useDiskCache`` is `true`, also consults
    /// ``UURemoteData/cachedDataExists(for:)``.
    ///
    /// - Parameter key: The remote URL string used as the cache key.
    /// - Returns: `true` when the image or its raw bytes are available locally.
    public func isDownloaded( for key: String) async -> Bool
    {
        if self.systemImageCache.object(forKey: key as NSString) != nil
        {
            return true
        }

        if UURemoteImage.useDiskCache
        {
            return await remoteData.cachedDataExists(for: key)
        }

        return false
    }

    /// Returns a cached or downloaded image for a remote URL.
    ///
    /// - Parameter key: The remote URL string used as the cache key.
    /// - Returns: A decoded image when immediately available from cache or after a synchronous
    ///   data hit, otherwise `nil` while a background download is in progress.
    public func image(for key: String) async -> UUImage?
    {
        return await image(for: key, remoteLoadCompletion: nil)
    }

    /// Returns a cached or downloaded image for a remote URL, invoking a completion when a
    /// background download and decode finishes.
    ///
    /// When the image is already in the memory cache, it is returned immediately and the
    /// completion is not called. When raw data is available from ``UURemoteData`` but not yet
    /// decoded, decoding runs on ``imageDecodeQueue`` before returning.
    ///
    /// When a network download is required, this method returns `nil` and the completion is
    /// invoked on ``imageCallbackQueue`` after decode completes or the download fails.
    ///
    /// - Parameters:
    ///   - key: The remote URL string used as the cache key.
    ///   - remoteLoadCompletion: An optional handler invoked when a background load and decode
    ///     completes. Ignored when an image is returned synchronously from cache.
    /// - Returns: A decoded image when immediately available, otherwise `nil`.
    public func image(for key: String, remoteLoadCompletion: UUImageLoadedCompletionBlock? = nil) async -> UUImage?
    {
        if let image = self.systemImageCache.object(forKey: key as NSString)
        {
            return image
        }

        let instance = self
        let imageKey = key
        let completion = remoteLoadCompletion
        let data = await remoteData.data(for: key)
        { data, error in
            let image = await instance.processImageData(for: imageKey, data: data)
            instance.deliverImageCompletion(completion, image: image, error: error)
        }

        if let imageData = data
        {
            return await processImageData(for: key, data: imageData)
        }

        return nil
    }

    private func deliverImageCompletion(
        _ completion: UUImageLoadedCompletionBlock?,
        image: UUImage?,
        error: Error?)
    {
        guard let completion else
        {
            return
        }

        imageCallbackQueue.async
        {
            completion(image, error)
        }
    }

    private func processImageData(for key: String, data: Data?) async -> UUImage?
    {
        let instance = self
        let imageKey = key
        let imageData = data
        let decodeQueue = imageDecodeQueue
        return await withCheckedContinuation
        { continuation in
            decodeQueue.async
            {
                Task
                {
                    let image = await instance.decodeAndCacheImage(for: imageKey, data: imageData)
                    continuation.resume(returning: image)
                }
            }
        }
    }

    private func decodeAndCacheImage(for key: String, data: Data?) async -> UUImage?
    {
        if let imageData = data, let image = UUImage(data: imageData)
        {
            var preparedImage = image

            // If available, prepare the image
            #if canImport(UIKit)
            preparedImage = await image.byPreparingForDisplay() ?? image
            #endif

            self.systemImageCache.setObject(preparedImage, forKey: key as NSString)

            if UURemoteImage.useDiskCache
            {
                var md = await remoteData.metaData(for: key)
                md[MetaData.ImageWidth] = NSNumber(value: Float(image.size.width))
                md[MetaData.ImageHeight] = NSNumber(value: Float(image.size.height))
                await remoteData.set(metaData: md, for: key)
            }

            notifyImageDownloaded(key)

            return image
        }

        return nil
    }

    private func notifyImageDownloaded(_ key: String)
    {
        let queue = imageNotificationQueue
        queue.async
        {
            var metaData : [String:Any] = [:]
            metaData[UURemoteData.NotificationKeys.RemotePath] = key
            NotificationCenter.default.post(name: Notifications.ImageDownloaded, object: nil, userInfo: metaData)
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    // Private implementation
    ////////////////////////////////////////////////////////////////////////////
    private let systemImageCache = NSCache<NSString, UUImage>()

    private struct MetaData
    {
        static let ImageWidth = "ImageWidth"
        static let ImageHeight = "ImageHeight"
    }

}
