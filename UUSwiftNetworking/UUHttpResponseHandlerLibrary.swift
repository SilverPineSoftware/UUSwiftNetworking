//
//  UUHttpResponseHandlerLibrary.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/19/21.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import UUSwiftCore


public class UUHttpResponseHandlerLibrary {

	public static let shared = UUHttpResponseHandlerLibrary()

	public var installedHandlers : [String:UUHttpResponseHandler] {
		return self.responseHandlers
	}

	public func registerResponseHandler(_ handler : UUHttpResponseHandler)
	{
		for mimeType in handler.supportedMimeTypes
		{
			responseHandlers[mimeType] = handler
		}
	}


	// //////////////////////////////////////////////////////////////////////////////////////////// //
	// Private interface
	// //////////////////////////////////////////////////////////////////////////////////////////// //

	private init() {
		self.installDefaultResponseHandlers()
	}

	private func installDefaultResponseHandlers()
	{
		registerResponseHandler(UUJsonResponseHandler())
		registerResponseHandler(UUTextResponseHandler())
		registerResponseHandler(UUBinaryResponseHandler())
		registerResponseHandler(UUImageResponseHandler())
		registerResponseHandler(UUFormEncodedResponseHandler())
	}

	private var responseHandlers : [String:UUHttpResponseHandler] = [:]

}
