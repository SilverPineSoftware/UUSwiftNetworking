//
//  UUStringExtensionsTests.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/28/26.
//

import XCTest
@testable import UUSwiftNetworking

final class UUStringExtensionsTests: XCTestCase
{
    // MARK: - uuUrlScheme

    func test_uuUrlScheme_parsesHttpsScheme()
    {
        XCTAssertEqual("https://api.example.com/path".uuUrlScheme, "https")
    }

    func test_uuUrlScheme_parsesCustomScheme()
    {
        XCTAssertEqual("uu-networking://login".uuUrlScheme, "uu-networking")
    }

    func test_uuUrlScheme_returnsNilWhenSchemeIsMissing()
    {
        XCTAssertNil("api.example.com/path".uuUrlScheme)
    }

    // MARK: - uuUrlHost

    func test_uuUrlHost_parsesHttpsHost()
    {
        XCTAssertEqual("https://api.example.com/path".uuUrlHost, "api.example.com")
    }

    func test_uuUrlHost_parsesCustomSchemeHost()
    {
        XCTAssertEqual("uu-networking://login/callback".uuUrlHost, "login")
    }

    func test_uuUrlHost_returnsNilForRelativePath()
    {
        XCTAssertNil("/login/callback".uuUrlHost)
    }

    // MARK: - uuUrlQueryItems

    func test_uuUrlQueryItems_parsesQueryItems()
    {
        let items = "uu-networking://login?ticket=abc&state=xyz".uuUrlQueryItems
        XCTAssertEqual(items?.count, 2)
        XCTAssertEqual(items?.first(where: { $0.name == "ticket" })?.value, "abc")
        XCTAssertEqual(items?.first(where: { $0.name == "state" })?.value, "xyz")
    }

    func test_uuUrlQueryItems_preservesItemsWithoutValues()
    {
        let item = "https://example.com/path?debug".uuUrlQueryItems?.first
        XCTAssertEqual(item?.name, "debug")
        XCTAssertNil(item?.value)
    }

    func test_uuUrlQueryItems_returnsNilWhenQueryIsMissing()
    {
        XCTAssertNil("https://example.com/path".uuUrlQueryItems)
    }

    // MARK: - uuUrlPath

    func test_uuUrlPath_parsesHttpsPath()
    {
        XCTAssertEqual("https://example.com/login/callback".uuUrlPath, "/login/callback")
    }

    func test_uuUrlPath_parsesCustomSchemePath()
    {
        XCTAssertEqual("uu-networking://login/callback".uuUrlPath, "/callback")
    }

    func test_uuUrlPath_returnsEmptyStringWhenAbsoluteUrlHasNoPath()
    {
        XCTAssertEqual("https://example.com".uuUrlPath, "")
    }

    func test_uuUrlPath_parsesRelativePath()
    {
        XCTAssertEqual("/login/callback".uuUrlPath, "/login/callback")
    }
}
