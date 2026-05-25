//
//  ParserTestSupport.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 5/24/26.
//

import Foundation
@testable import UUSwiftNetworking

enum ParserTestSupport
{
    static let defaultUrl = "https://api.example.com/resource"

    static func urlRequest(url: String = defaultUrl) -> URLRequest
    {
        URLRequest(url: URL(string: url)!)
    }

    static func httpResponse(
        url: String = defaultUrl,
        statusCode: Int = 200,
        contentType: String? = nil,
        textEncoding: String? = nil
    ) -> HTTPURLResponse
    {
        var headers: [String: String] = [:]
        if let contentType
        {
            headers["Content-Type"] = contentType
        }
        if let textEncoding
        {
            headers["Content-Encoding"] = textEncoding
        }
        return HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }

    static func uuHttpRequest(url: String = defaultUrl) -> UUHttpRequest
    {
        UUHttpRequest(url: url)
    }
}

struct ParserTestPayload: Codable, Equatable
{
    var id: String = ""
    var count: Int = 0
}

struct ParserTestCodable: Codable, Equatable
{
    var fieldOne: String
    var fieldTwo: Int

    func jsonData() -> Data?
    {
        try? JSONEncoder().encode(self)
    }
}
