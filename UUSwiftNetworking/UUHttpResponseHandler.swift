//
//  UUHttpResponseHandler.swift
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

public protocol UUHttpResponseHandler
{
	var supportedMimeTypes : [String] { get }
	func parseResponse(_ data : Data, _ response: HTTPURLResponse, _ request: URLRequest) -> Any?
}

open class UUTextResponseHandler : NSObject, UUHttpResponseHandler
{
	public var supportedMimeTypes: [String]
	{
		return [UUContentType.textHtml, UUContentType.textPlain]
	}

	open func parseResponse(_ data: Data, _ response: HTTPURLResponse, _ request: URLRequest) -> Any?
	{
		var parsed : Any? = nil

		var responseEncoding : String.Encoding = .utf8

		if (response.textEncodingName != nil)
		{
			let cfEncoding = CFStringConvertIANACharSetNameToEncoding(response.textEncodingName as CFString?)
			responseEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
		}

		let stringResult : String? = String.init(data: data, encoding: responseEncoding)
		if (stringResult != nil)
		{
			parsed = stringResult
		}

		return parsed
	}
}

open class UUBinaryResponseHandler : NSObject, UUHttpResponseHandler
{
	open var supportedMimeTypes: [String]
	{
		return [UUContentType.binary]
	}

	open func parseResponse(_ data: Data, _ response: HTTPURLResponse, _ request: URLRequest) -> Any?
	{
		return data
	}
}

open class UUJsonResponseHandler : NSObject, UUHttpResponseHandler
{
	open var supportedMimeTypes: [String]
	{
		return [UUContentType.applicationJson, UUContentType.textJson]
	}

	open func parseResponse(_ data: Data, _ response: HTTPURLResponse, _ request: URLRequest) -> Any?
	{
		do
		{
			return try JSONSerialization.jsonObject(with: data, options: [])
		}
		catch (let err)
		{
			UUDebugLog("Error deserializing JSON: %@", String(describing: err))
		}

		return nil
	}
}

open class UUImageResponseHandler : NSObject, UUHttpResponseHandler
{
	public var supportedMimeTypes: [String]
	{
		return [UUContentType.imagePng, UUContentType.imageJpeg]
	}

	open func parseResponse(_ data: Data, _ response: HTTPURLResponse, _ request: URLRequest) -> Any?
	{
#if os(macOS)
		return NSImage.init(data: data)
#else
		return UIImage.init(data: data)
#endif
	}
}

open class UUFormEncodedResponseHandler : NSObject, UUHttpResponseHandler
{
	public var supportedMimeTypes: [String]
	{
		return [UUContentType.formEncoded]
	}

	open func parseResponse(_ data: Data, _ response: HTTPURLResponse, _ request: URLRequest) -> Any?
	{
		var parsed: [ String: Any ] = [:]

		if let s = String.init(data: data, encoding: .utf8)
        {
			let components = s.components(separatedBy: "&")
            
			for c in components
            {
				let pair = c.components(separatedBy: "=")
                
				if pair.count == 2
                {
					if let key = pair.first
                    {
						if let val = pair.last
                        {
							parsed[key] = val.removingPercentEncoding
						}
					}
				}
			}
		}

		return parsed
	}
}

open class UUJsonCodableResponseParser<T: Codable>: UUJsonResponseHandler
{
    open override func parseResponse(_ data: Data, _ response: HTTPURLResponse, _ request: URLRequest) -> Any?
    {
        var result: Any? = nil
        
        let decoder = JSONDecoder()
        
        do
        {
            result = try decoder.decode(T.self, from: data)
        }
        catch let err
        {
            result = UUErrorFactory.createParseError(err, data, response, request)
        }
        
        return result
    }
}
