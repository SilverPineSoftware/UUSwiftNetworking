//
//  UUFormBody.swift
//  UUSwiftNetworking
//
//  Created by Jonathan Hays on 10/18/21.
//

import Foundation
import UUSwiftCore

/// Multipart form-data body (`multipart/form-data`) for file uploads and form fields.
///
/// Use ``add(field:value:contentType:encoding:)`` for text fields and ``addFile(fieldName:fileName:contentType:fileData:)``
/// for binary parts. Parts are encoded when ``encode()`` runs (typically via ``prepareToSend()``).
open class UUFormBody: UUHttpBody
{
    /// Boundary token embedded in the `Content-Type` header and part delimiters.
    public var formBoundary: String

    /// Default boundary used when none is supplied to ``init(formBoundary:)``.
    public static let defaultFormBoundary = "UUForm_PostBoundary"

    private var formBuilder = NSMutableData()

    /// Creates a multipart form body with the given boundary token.
    ///
    /// - Parameter formBoundary: Boundary string included in `Content-Type` and part delimiters.
    ///   Defaults to ``defaultFormBoundary``.
    public init(formBoundary: String = UUFormBody.defaultFormBoundary)
    {
        self.formBoundary = formBoundary
        super.init(
            contentType: "multipart/form-data; boundary=\(formBoundary)",
            contentEncoding: nil,
            content: nil
        )
    }

    /// Adds a text form field.
    ///
    /// - Parameters:
    ///   - field: Field name (`Content-Disposition` `name` attribute).
    ///   - value: Field value.
    ///   - contentType: Optional part `Content-Type` (defaults to ``UUContentType/textPlain``).
    ///   - encoding: String encoding used for ``value``.
    public func add(
        field: String,
        value: String,
        contentType: String? = UUContentType.textPlain,
        encoding: String.Encoding = .utf8
    )
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

    /// Adds a file part with filename and content type metadata.
    ///
    /// - Parameters:
    ///   - fieldName: Form field name.
    ///   - fileName: Filename reported to the server.
    ///   - contentType: MIME type of the file bytes.
    ///   - fileData: Raw file content.
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

    /// Encodes accumulated form parts and the closing boundary.
    open override func encode() -> Data?
    {
        return formData()
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
        if formBuilder.length > 0
        {
            if let bytes = "\r\n".data(using: .utf8)
            {
                formBuilder.append(bytes)
            }
        }
    }

    private func formData() -> Data?
    {
        guard let tmp = formBuilder.mutableCopy() as? NSMutableData,
              let endBoundaryBytes = endBoundaryBytes()
        else
        {
            return nil
        }

        tmp.append(endBoundaryBytes)
        return tmp as Data
    }
}
