//
//  UUJsonBody.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/6/26.
//

import Foundation

/// JSON request body that serializes a `Codable` model with ``JSONEncoder``.
///
/// Content type is ``UUContentType/applicationJson``. Encoding is deferred until ``encode()``
/// or ``prepareToSend()``.
///
/// Assign ``jsonEncoder`` before encoding when custom encoding options are required.
open class UUJsonBody<T: Codable>: UUHttpBody
{
    let codableContent: T

    /// Encoder used by ``encode()``; customize date strategies, key formatting, and so on.
    public var jsonEncoder = JSONEncoder()

    /// Creates a JSON body for the given model.
    ///
    /// - Parameter content: Value serialized via ``jsonEncoder``.
    public required init(_ content: T)
    {
        self.codableContent = content

        super.init(contentType: UUContentType.applicationJson, contentEncoding: nil, content: nil)
    }

    /// Serializes ``codableContent`` to UTF-8 JSON bytes, or `nil` when encoding fails.
    open override func encode() -> Data?
    {
        return try? jsonEncoder.encode(codableContent)
    }
}
