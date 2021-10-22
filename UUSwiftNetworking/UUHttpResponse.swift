//
//  UUHttpResponse.swift
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


public class UUHttpResponse : NSObject
{
	public let httpRequest : UUHttpRequest
	public let httpResponse : HTTPURLResponse?
	public let rawResponse : Data?
	public let downloadTime : TimeInterval
	private let nativeError : Error?

	init(request : UUHttpRequest, response : HTTPURLResponse?, data : Data?, error : Error?, elapsedTime : TimeInterval = Date.timeIntervalSinceReferenceDate)
	{
		rawResponse = data
		httpRequest = request
		httpResponse = response
		nativeError = error
		downloadTime = elapsedTime
	}

	public func parsedObject<T>() -> T? where T : Codable {
		if let data = self.rawResponse {
			let decoder = JSONDecoder()
			do {
				return try decoder.decode(T.self, from: data)
			}
			catch {
			}
		}
		return nil
	}

	public func parsedArray<T:Codable>() -> [T]? {
		if let data = self.rawResponse {

			do
			{
				if let array = try JSONSerialization.jsonObject(with: data, options: []) as? [T] {
					return array
				}
			}
			catch {

			}
		}
		return nil
	}


	public var parsedResponse : Any? {

		if let response = self.httpResponse,
		   let rawResponse = self.rawResponse {
			return self.parseResponse(self.httpRequest, response, rawResponse)
		}

		return nil
	}

	public var httpError : Error? {

		var err = nativeError
		var httpResponseCode : Int = 200

		if let response = self.httpResponse
		{
			httpResponseCode = response.statusCode
		}

		if !isHttpSuccessResponseCode(httpResponseCode)
		{
			err = UUErrorFactory.createHttpError(self.httpRequest, self.httpResponse)
		}

		return err
	}

	private func parseResponse(_ request : UUHttpRequest, _ httpResponse : HTTPURLResponse?, _ data : Data?) -> Any?
	{
		if (httpResponse != nil)
		{
			let httpRequest = request.httpRequest

			let mimeType = httpResponse!.mimeType
			var handler = request.responseHandler

			if (handler == nil && mimeType != nil)
			{
				handler =  UUHttpResponseHandlerLibrary.shared.installedHandlers[mimeType!]
			}

			if (handler != nil && data != nil && httpRequest != nil)
			{
				let parsedResponse = handler!.parseResponse(data!, httpResponse!, httpRequest!)
				return parsedResponse
			}
		}

		return nil
	}

	private func isHttpSuccessResponseCode(_ responseCode : Int) -> Bool
	{
		return (responseCode >= 200 && responseCode < 300)
	}


}
