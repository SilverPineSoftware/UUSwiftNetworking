//
//  UURemoteImageV2.swift
//  UUSwiftNetworking
//
//  A remote image loader built on the generic ``UURemoteObject`` base.
//
//  License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import Foundation
import CoreGraphics
import UUSwiftCore

/// A remote image loader with layered caching, decode + display preparation, and dimension
/// metadata persistence.
///
/// `UURemoteImageV2` specializes ``UURemoteObject`` for ``UUImage``:
///
/// - The memory cache holds decoded ``UUImage`` instances.
/// - The disk cache holds the raw image bytes plus persisted pixel dimensions.
/// - ``decode(_:for:)`` builds the image and, on UIKit platforms, prepares it for display off the
///   main thread.
///
/// All decode, download, and disk work runs off the main thread. See ``UURemoteObject`` for the
/// full caching, coalescing, cancellation, and threading model.
open class UURemoteImageV2: UURemoteObject<UUImage>, @unchecked Sendable
{
    /// Disk-cache metadata keys written by this loader.
    public struct MetadataKeys
    {
        /// The decoded image width, in points, stored as an `NSNumber`.
        public static let imageWidth = "UURemoteImageV2.width"

        /// The decoded image height, in points, stored as an `NSNumber`.
        public static let imageHeight = "UURemoteImageV2.height"
    }

    /// A shared image loader using ``UUDataCache/shared`` and a default ``UURemoteObjectApi``.
    public static let shared = UURemoteImageV2()

    /// Creates a remote image loader.
    ///
    /// - Parameters:
    ///   - dataCache: The disk cache used for byte and dimension persistence. Defaults to
    ///     ``UUDataCache/shared``.
    ///   - remoteApi: The API client used for network requests. Inject a subclass to add
    ///     authorization, custom sessions, or a bespoke response handler.
    public override init(
        dataCache: UUDataCacheProtocol = UUDataCache.shared,
        remoteApi: UURemoteObjectApi = UURemoteObjectApi())
    {
        super.init(dataCache: dataCache, remoteApi: remoteApi)
    }

    /// Returns a decoded image for a URL from the memory cache, disk cache, or network.
    ///
    /// Equivalent to ``UURemoteObject/object(for:)`` for the ``UUImage`` value type.
    open func image(for url: String) async throws -> UUImage
    {
        try await object(for: url)
    }

    /// Returns the decoded image already present in the memory cache, if any.
    public func cachedImage(for url: String) -> UUImage?
    {
        memoryCachedObject(for: url)
    }

    /// Returns the persisted pixel dimensions for a URL, if available.
    ///
    /// Dimensions are written to disk-cache metadata after a successful decode.
    ///
    /// - Parameter url: The remote URL string used as the cache key.
    /// - Returns: The stored size, or `nil` when dimensions have not been persisted.
    public func imageSize(for url: String) async -> CGSize?
    {
        let metaData = await dataCache.metaData(for: url)

        guard let width = metaData[MetadataKeys.imageWidth] as? NSNumber,
              let height = metaData[MetadataKeys.imageHeight] as? NSNumber else
        {
            return nil
        }

        return CGSize(width: CGFloat(width.doubleValue), height: CGFloat(height.doubleValue))
    }

    // MARK: - UURemoteObject overrides

    open override func decode(_ data: Data, for url: String) async throws -> UUImage
    {
        guard let image = UUImage(data: data) else
        {
            throw UURemoteObjectError.decodeFailed(url)
        }

        #if canImport(UIKit)
        if let prepared = await image.byPreparingForDisplay()
        {
            return prepared
        }
        #endif

        return image
    }

    open override func cost(for value: UUImage) -> Int
    {
        #if canImport(UIKit)
        if let cgImage = value.cgImage
        {
            return cgImage.bytesPerRow * cgImage.height
        }
        #endif

        // Fallback estimate: 4 bytes per point (RGBA).
        return Int(value.size.width * value.size.height * 4.0)
    }

    open override func additionalMetadata(for value: UUImage, data: Data, url: String) async -> [String: Any]
    {
        [
            MetadataKeys.imageWidth: NSNumber(value: Double(value.size.width)),
            MetadataKeys.imageHeight: NSNumber(value: Double(value.size.height))
        ]
    }
}
