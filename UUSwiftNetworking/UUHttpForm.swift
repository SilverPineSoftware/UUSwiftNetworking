//
//  UUHttpForm.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore


public class UUHttpForm : NSObject
{
	public var formBoundary: String = "UUForm_PostBoundary"
	private var formBuilder: NSMutableData = NSMutableData()

	public func add(field: String, value: String, contentType: String? = UUContentType.textPlain, encoding: String.Encoding = .utf8)
	{
		appendNewLineIfNeeded()

		if let boundaryBytes = boundaryBytes(),
		   let fieldNameBytes = "Content-Disposition: form-data; name=\"\(field)\"\r\n".data(using: .utf8),
		   let fieldValueBytes = value.data(using: encoding)
		{
			formBuilder.append(boundaryBytes)
			formBuilder.append(fieldNameBytes)
            
            if let contentType = contentType,
               let contentTypeBytes = contentTypeBytes(contentType)
            {
                formBuilder.append(contentTypeBytes)
            }
            
            appendNewLineIfNeeded()
			formBuilder.append(fieldValueBytes)
		}
	}
    
	public func addFile(fieldName: String, fileName: String, contentType: String, fileData: Data)
	{
		appendNewLineIfNeeded()

		if let boundaryBytes = boundaryBytes(),
		   let fieldNameBytes = "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8),
		   let contentTypeBytes = contentTypeBytes(contentType)
		{
			formBuilder.append(boundaryBytes)
			formBuilder.append(fieldNameBytes)
			formBuilder.append(contentTypeBytes)
			formBuilder.append(fileData)
		}
	}

	private func boundaryBytes() -> Data?
	{
		return "--\(formBoundary)\r\n".data(using: .utf8)
	}

	private func endBoundaryBytes() -> Data?
	{
		return "\r\n--\(formBoundary)--\r\n".data(using: .utf8)
	}

	private func contentTypeBytes(_ contentType: String) -> Data?
	{
		return "Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)
	}

	private func appendNewLineIfNeeded()
	{
		if (formBuilder.length > 0)
		{
			if let bytes = "\r\n".data(using: .utf8)
			{
				formBuilder.append(bytes)
			}
		}
	}

	public func formData() -> Data?
	{
		guard let tmp = formBuilder.mutableCopy() as? NSMutableData, let endBoundaryBytes = endBoundaryBytes() else
		{
			return nil
		}

		tmp.append(endBoundaryBytes)
		return tmp as Data
	}

	public func formContentType() -> String
	{
		return "multipart/form-data; boundary=\(formBoundary)"
	}
}

