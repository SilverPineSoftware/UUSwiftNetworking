//
//  HandlerTestSupport.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import Foundation
@testable import UUSwiftNetworking

enum HandlerTestSupport
{
    static let defaultUrl = "https://api.example.com/resource"

    static func uuRequest(url: String = defaultUrl) -> UUHttpRequest
    {
        let request = UUHttpRequest(url: url)
        request.httpRequest = URLRequest(url: URL(string: url)!)
        return request
    }

    static func httpResponse(
        url: String = defaultUrl,
        statusCode: Int = 200,
        contentType: String = UUContentType.binary
    ) -> HTTPURLResponse
    {
        HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType]
        )!
    }

    /// Handler that always uses the given success and error parsers.
    static func handler(
        success: UUHttpDataParser,
        error: UUHttpDataParser
    ) -> UUBaseResponseHandler
    {
        ConfigurableHandler(successParser: success, errorParser: error)
    }

    /// Lightweight parser for handler tests without subclassing open parser types.
    static func labelParser(_ label: String) -> UUHttpDataParser
    {
        LabelParser(label: label)
    }
}

private final class LabelParser: UUHttpDataParser
{
    let label: String

    init(label: String)
    {
        self.label = label
    }

    func parse(data: Data, response: HTTPURLResponse, request: URLRequest) async -> Any?
    {
        label
    }
}

private final class ConfigurableHandler: UUBaseResponseHandler
{
    private let configuredSuccess: UUHttpDataParser
    private let configuredError: UUHttpDataParser

    init(successParser: UUHttpDataParser, errorParser: UUHttpDataParser)
    {
        configuredSuccess = successParser
        configuredError = errorParser
        super.init()
    }

    required init()
    {
        configuredSuccess = UUBinaryDataParser()
        configuredError = UUBinaryDataParser()
        super.init()
    }

    override var successParser: UUHttpDataParser
    {
        configuredSuccess
    }

    override var errorParser: UUHttpDataParser
    {
        configuredError
    }
}
