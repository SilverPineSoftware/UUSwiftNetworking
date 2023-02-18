//
//  UUHttp.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import UUSwiftCore

public typealias UUQueryStringArgs = [AnyHashable:Any]
public typealias UUHttpHeaders = [AnyHashable:Any]

public enum UUHttpMethod : String
{
	case get = "GET"
	case post = "POST"
	case put = "PUT"
	case delete = "DELETE"
	case head = "HEAD"
	case patch = "PATCH"
}


public struct UUContentType
{
	public static let applicationJson  = "application/json"
	public static let textJson         = "text/json"
	public static let textHtml         = "text/html"
	public static let textPlain        = "text/plain"
	public static let binary           = "application/octet-stream"
	public static let imagePng         = "image/png"
	public static let imageJpeg        = "image/jpeg"
	public static let formEncoded      = "application/x-www-form-urlencoded"
}

public struct UUHeader
{
	public static let contentLength = "Content-Length"
	public static let contentType = "Content-Type"
}

public extension Int
{
    func uuIsHttpSuccess() -> Bool
    {
        return self >= 200 && self <= 299
    }
}
