//
//  UUHttpDataParser.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/23/21.
//

import Foundation
import UUSwiftCore

fileprivate let LOG_TAG = "UUHttpDataParser"

/// Converts raw HTTP response bytes into a parsed object (or an ``Error``) for ``UUHttpResponseHandler``.
///
/// Parsers are selected by response handlers—typically a success parser for 2xx responses and an error parser
/// for non-success status codes. Implementations may return:
/// - A decoded model (`String`, `Data`, `Codable` type, `[String: Any]`, etc.)
/// - `nil` when parsing cannot produce a result
/// - An ``Error`` (commonly from ``UUErrorFactory``) to short-circuit handler error mapping
public protocol UUHttpDataParser
{
    /// Parses response body data using the HTTP response and originating request for context.
    func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
}
