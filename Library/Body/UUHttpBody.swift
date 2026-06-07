//
//  UUHttpBody.swift
//
//
//  Created by Ryan DeVore on 2/17/23.
//

import Foundation

/// Base type for HTTP request bodies attached to ``UUHttpRequest/body``.
///
/// Subclasses override ``encode()`` to produce wire-format bytes lazily. Call ``prepareToSend()``
/// before transmission to obtain the payload and the `Content-Type` / `Content-Length`
/// headers (and optional `Content-Encoding`) that should accompany it.
///
/// The designated initializer stores a fixed ``content`` for simple pass-through bodies.
/// ``UUJsonBody`` and ``UUFormBody`` defer serialization until ``encode()`` is invoked.
///
/// - SeeAlso: ``UUJsonBody``, ``UUFormBody``, ``UUHttpRequest/body``
open class UUHttpBody
{
    /// MIME type sent as the `Content-Type` header.
    public let contentType: String

    /// Optional value for the `Content-Encoding` header.
    public let contentEncoding: String?

    /// Fixed payload returned directly from ``encode()`` when provided at initialization.
    public let content: Data?

    /// Creates a body with the given MIME type and optional fixed payload.
    ///
    /// - Parameters:
    ///   - contentType: Value for the `Content-Type` header.
    ///   - contentEncoding: Optional `Content-Encoding` header value.
    ///   - content: Pre-encoded payload, or `nil` when subclasses produce bytes in ``encode()``.
    public init(contentType: String, contentEncoding: String? = nil, content: Data?)
    {
        self.contentType = contentType
        self.contentEncoding = contentEncoding
        self.content = content
    }

    /// Produces the wire-format body bytes, or `nil` when serialization fails.
    open func encode() -> Data?
    {
        return content
    }

    /// Encodes the body and builds the headers required to send it.
    ///
    /// - Returns: Success with `(payload, headers)` when ``encode()`` returns a non-empty
    ///   `Data` value; failure with ``UUHttpSessionError/serializeFailure`` when encoding
    ///   returns `nil` or an empty payload.
    open func prepareToSend() -> Result<(Data, UUHttpHeaders), Error>
    {
        guard let encodedBody = encode() else
        {
            return .failure(UUErrorFactory.createError(.serializeFailure, nil))
        }

        let encodedBodyLength = encodedBody.count
        if encodedBodyLength > 0
        {
            let headers = buildHeaders(encodedBodyLength)
            return .success((encodedBody, headers))
        }
        else
        {
            // No exceptions thrown but a non-null UUHttpBody object should result in a non-null payload
            return .failure(UUErrorFactory.createError(.serializeFailure, nil))
        }
    }

    /// Builds `Content-Type`, `Content-Length`, and optional `Content-Encoding` headers.
    ///
    /// - Parameter contentLength: Byte length of the encoded body.
    open func buildHeaders(_ contentLength: Int) -> UUHttpHeaders
    {
        var headers = UUHttpHeaders()
        headers[UUHttpHeader.contentType] = contentType
        headers[UUHttpHeader.contentLength] = contentLength

        if let contentEncoding = contentEncoding
        {
            headers[UUHttpHeader.contentEncoding] = contentEncoding
        }

        return headers
    }
}
