//
//  UURemoteDataV2.swift
//  UUSwiftNetworking
//
//  A focused remote binary data loader built on the generic ``UURemoteObject`` base.
//
//  License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//

import Foundation
import UUSwiftCore

/// Backwards-compatible alias for the loader error type, shared by all ``UURemoteObject`` loaders.
public typealias UURemoteDataV2Error = UURemoteObjectError

/// Backwards-compatible alias for the download API client, shared by all ``UURemoteObject`` loaders.
public typealias UURemoteDataV2Api = UURemoteObjectApi

/// Backwards-compatible alias for the binary response handler, shared by all ``UURemoteObject``
/// loaders.
public typealias UURemoteDataV2ResponseHandler = UURemoteObjectResponseHandler

/// Returns the bytes for a URL from the memory cache, disk cache, or network.
///
/// `UURemoteDataV2` is a thin specialization of ``UURemoteObject`` for raw ``Data``: the memory
/// cache holds `Data` and decoding is an identity pass-through. See ``UURemoteObject`` for the full
/// description of the caching, coalescing, cancellation, and threading model.
public protocol UURemoteDataV2Protocol: Sendable
{
    /// Returns the bytes for a URL from the memory cache, disk cache, or network.
    ///
    /// - Parameter url: The remote URL string, also used as the cache key.
    /// - Returns: The resolved data.
    /// - Throws: ``UURemoteObjectError`` for invalid input or empty responses, the underlying HTTP
    ///   or network error on failure, or `CancellationError` if the awaiting task is cancelled.
    func data(for url: String) async throws -> Data
}

/// A remote binary data loader with layered caching and single-flight network coalescing.
///
/// `UURemoteDataV2` specializes ``UURemoteObject`` for raw ``Data``. The memory cache holds `Data`
/// and ``UURemoteObject/decode(_:for:)`` is an identity pass-through, so a single ``data(for:)``
/// call resolves bytes from the memory cache, disk cache, or a coalesced network download.
///
/// See ``UURemoteObject`` for the full description of caching, coalescing, cancellation, threading,
/// and the overridable pipeline hooks (``UURemoteObject/transform(downloadedData:for:)`` and
/// friends).
open class UURemoteDataV2: UURemoteObject<Data>, UURemoteDataV2Protocol, @unchecked Sendable
{
    /// A shared loader using ``UUDataCache/shared`` and a default ``UURemoteDataV2Api``.
    public static let shared = UURemoteDataV2()

    /// Creates a remote data loader.
    ///
    /// - Parameters:
    ///   - dataCache: The disk cache used for persistence. Defaults to ``UUDataCache/shared``.
    ///   - remoteApi: The API client used for network requests. Inject a subclass to add
    ///     authorization, custom sessions, or a bespoke response handler.
    public override init(
        dataCache: UUDataCacheProtocol = UUDataCache.shared,
        remoteApi: UURemoteDataV2Api = UURemoteDataV2Api())
    {
        super.init(dataCache: dataCache, remoteApi: remoteApi)
    }

    /// Returns the bytes for a URL from the memory cache, disk cache, or network.
    ///
    /// Equivalent to ``UURemoteObject/object(for:)`` for the `Data` value type.
    open func data(for url: String) async throws -> Data
    {
        try await object(for: url)
    }

    /// Returns the bytes already present in the memory cache, if any.
    public func memoryCachedData(for url: String) -> Data?
    {
        memoryCachedObject(for: url)
    }
}
