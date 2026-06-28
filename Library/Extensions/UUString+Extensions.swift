//
//  UUString+Extensions.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 6/28/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

public extension String
{
    /// The URL scheme parsed from this string.
    ///
    /// For example, `https://example.com` returns `https`, and
    /// `uu-networking://login` returns `uu-networking`.
    var uuUrlScheme: String?
    {
        URLComponents(string: self)?.scheme
    }
    
    /// The URL host parsed from this string, when one is present.
    ///
    /// For example, `https://example.com/path` returns `example.com`, and
    /// `uu-networking://login` returns `login`.
    var uuUrlHost: String?
    {
        URLComponents(string: self)?.host
    }
    
    /// The URL query items parsed from this string, when a query is present.
    ///
    /// For example, `https://example.com/path?ticket=abc&state=xyz` returns
    /// query items named `ticket` and `state`.
    var uuUrlQueryItems: [URLQueryItem]?
    {
        URLComponents(string: self)?.queryItems
    }
    
    /// The URL path parsed from this string.
    ///
    /// Absolute URLs without a path return an empty string. For example,
    /// `https://example.com` returns `""`, while
    /// `https://example.com/login/callback` returns `/login/callback`.
    var uuUrlPath: String?
    {
        URLComponents(string: self)?.path
    }
}
