//
//  UURemoteDataTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 10/18/21.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@testable import UUSwiftNetworking

class LiveUURemoteDataTests: BaseOnlineTest
{
    override func setUpWithError() throws
    {
        try super.setUpWithError()
    }

    override func setUp() async throws
    {
        try await super.setUp()

        await remoteDataForTest.dataCache.clearCache()
        remoteDataForTest.clearMemoryCache()
        remoteDataForTest.maxActiveRequests = 50
        remoteDataForTest.dataCache.contentExpirationLength = 30 * 24 * 60 * 60
    }

    open var remoteDataForTest: UURemoteData
    {
        let api = UURemoteData.shared
        api.networkTimeout = 300.0
        return api
    }

    open var concurrentDownloadCount: Int
    {
        return 10
    }

    private var testUrl: String
    {
        return testConfig.fullDownloadFileUrl
    }

    // MARK: - Tests

    func test_fetchNoLocal() async
    {
        let remoteData = remoteDataForTest
        let key = testUrl

        let exp = expectation(
            forNotification: UURemoteData.Notifications.DataDownloaded,
            object: nil
        ) { notification in
            notification.uuRemoteDataPath == key
        }

        var data = await remoteData.data(for: key)
        XCTAssertNil(data)

        await fulfillment(of: [exp], timeout: remoteData.networkTimeout)

        let md = await remoteData.metaData(for: key)
        data = await remoteData.data(for: key)
        XCTAssertNotNil(data)
        XCTAssertNotNil(md)
    }

    func test_fetchFromBadUrl() async
    {
        let remoteData = remoteDataForTest
        let key = "http://this.is.a.fake.url/non_existent.jpg"

        let exp = expectation(
            forNotification: UURemoteData.Notifications.DataDownloadFailed,
            object: nil
        ) { notification in
            notification.uuRemoteDataPath == key
        }

        let data = await remoteData.data(for: key)
        XCTAssertNil(data)

        await fulfillment(of: [exp], timeout: remoteData.networkTimeout)

        let dataAfterNotification = await remoteData.data(for: key)
        XCTAssertNil(dataAfterNotification)
    }

    func test_fetchExisting() async throws
    {
        try await uploadTestPhoto()

        let remoteData = remoteDataForTest
        let key = testUrl

        let exp = expectation(description: #function)

        let existing = await remoteData.data(for: key)
        { result, err in
            XCTAssertNil(err)
            XCTAssertNotNil(result)
            exp.fulfill()
        }

        XCTAssertNil(existing)

        await fulfillment(of: [exp], timeout: remoteData.networkTimeout)

        let data = await remoteData.data(for: key)
        XCTAssertNotNil(data)
    }

    func test_downloadMultiple_largeFiles_noDuplicates() async
    {
        await do_concurrentDownloadTest(count: concurrentDownloadCount, large: true, includeDuplicates: false)
    }

    func test_downloadMultiple_smallFiles_noDuplicates() async
    {
        await do_concurrentDownloadTest(count: concurrentDownloadCount, large: false, includeDuplicates: false)
    }

    func test_downloadMultiple_largeFiles_withDuplicates() async
    {
        await do_concurrentDownloadTest(count: concurrentDownloadCount, large: true, includeDuplicates: true)
    }

    func test_downloadMultiple_smallFiles_withDuplicates() async
    {
        await do_concurrentDownloadTest(count: concurrentDownloadCount, large: false, includeDuplicates: true)
    }

    // MARK: - Concurrent download support

    private func do_concurrentDownloadTest(count: Int, large: Bool, includeDuplicates: Bool) async
    {
        let remoteData = remoteDataForTest

        let imageUrls = await getImageUrls(count: count, large: large)
        XCTAssertTrue(imageUrls.count > 0)

        await withTaskGroup(of: Void.self)
        { group in
            for (index, url) in imageUrls.enumerated()
            {
                UUTestLog("Fetching Data for URL: \(url)")

                group.addTask
                {
                    await self.runConcurrentDownloadIteration(
                        remoteData: remoteData,
                        url: url,
                        index: index,
                        label: "outer",
                        expectNilBeforeCompletion: !includeDuplicates)
                }

                if includeDuplicates
                {
                    group.addTask
                    {
                        try? await Task.sleep(nanoseconds: 50_000)

                        await self.runConcurrentDownloadIteration(
                            remoteData: remoteData,
                            url: url,
                            index: index,
                            label: "inner",
                            expectNilBeforeCompletion: false)
                    }
                }
            }
        }

        UUTestLog("All concurrent downloads complete")
    }

    private func runConcurrentDownloadIteration(
        remoteData: UURemoteData,
        url: String,
        index: Int,
        label: String,
        expectNilBeforeCompletion: Bool) async
    {
        let (result, err) = await fetchRemoteData(
            remoteData: remoteData,
            url: url,
            expectNilBeforeCompletion: expectNilBeforeCompletion)

        assertDownloadResult(url: url, index: index, label: label, result: result, err: err)
        UUTestLog("Iteration Complete - \(index) - \(label)")
    }

    private func fetchRemoteData(
        remoteData: UURemoteData,
        url: String,
        expectNilBeforeCompletion: Bool) async -> (Data?, Error?)
    {
        if expectNilBeforeCompletion
        {
            let existing = await remoteData.data(for: url)
            XCTAssertNil(existing)
        }

        return await withCheckedContinuation
        { continuation in
            let resumeOnce = ResumeOnce(continuation)

            Task
            {
                let immediate = await remoteData.data(for: url)
                { data, error in
                    resumeOnce.resume((data, error))
                }

                if let immediate
                {
                    resumeOnce.resume((immediate, nil))
                }
            }
        }
    }

    private func assertDownloadResult(
        url: String,
        index: Int,
        label: String,
        result: Data?,
        err: Error?)
    {
        if let httpCode = err?.uuHttpStatusCode
        {
            switch httpCode
            {
                case 403:
                    UUTestLog("Skipping 403 Forbidden for \(url) [\(label)]")

                case 404:
                    UUTestLog("Skipping 404 Not Found for \(url) [\(label)]")

                default:
                    XCTAssertNotNil(result, "Expected data for iteration \(index) [\(label)]")
                    XCTAssertNil(err, "Expected no error for iteration \(index) [\(label)]")
            }
        }
        else if let err
        {
            XCTFail("Unexpected error for iteration \(index) [\(label)]: \(err)")
        }
        else
        {
            XCTAssertNotNil(result, "Expected data for iteration \(index) [\(label)]")
        }
    }

    private func getImageUrls(count: Int, large: Bool) async -> [String]
    {
        let cfg = ShutterstockApiConfig(
            clientKey: testConfig.shutterstockClientKey,
            clientSecret: testConfig.shutterstockClientSecret
        )

        let api = ShutterstockApi()
        api.config = cfg

        let result = await api.searchImages(query: "forest", count: count, large: large)
        return (try? result.get()) ?? []
    }

    // MARK: - Upload helpers

    private func uploadTestPhoto() async throws
    {
        let url = testConfig.formPostUrl

        let request = UUHttpRequest(url: url, method: .post)

        let form = UUFormBody()
        form.add(field: "FileType", value: "Image", contentType: "text/plain")

        let fileName = testConfig.uploadImageFileName

        if let filePath = testConfig.uploadImageFilePath,
           let data = try? Data(contentsOf: filePath)
        {
            form.addFile(fieldName: "uu_file", fileName: fileName, contentType: "image/jpeg", fileData: data)
        }

        request.body = form

        let response = await remoteDataForTest.remoteApi.executeRequest(request)
        XCTAssertNil(response.httpError)

        try await verifyUploadedFile(fileName)
    }

    private func verifyUploadedFile(_ fileName: String) async throws
    {
        let url = "\(testConfig.downloadFileUrl)?uu_file=\(fileName)"

        let request = UUHttpRequest(url: url, method: .get)

        let response = await remoteDataForTest.remoteApi.executeRequest(request)

        XCTAssertNotNil(response.parsedResponse)
        XCTAssertNil(response.httpError)

        #if canImport(UIKit)
        let img = response.parsedResponse as? UIImage
        XCTAssertNotNil(img)
        #elseif canImport(AppKit)
        let img = response.parsedResponse as? NSImage
        XCTAssertNotNil(img)
        #else
        XCTAssertNotNil(response.parsedResponse)
        #endif
    }
}

private final class ResumeOnce<T: Sendable>: @unchecked Sendable
{
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>)
    {
        self.continuation = continuation
    }

    func resume(_ value: T)
    {
        guard let continuation else
        {
            return
        }

        self.continuation = nil
        continuation.resume(returning: value)
    }
}
