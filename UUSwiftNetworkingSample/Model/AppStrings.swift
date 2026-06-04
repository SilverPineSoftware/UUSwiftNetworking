//
//  AppStrings.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/3/26.
//

import Foundation

func formatVersionString() -> String
{
    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
       let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    {
        return "\(version) (\(build))"
    }
    else
    {
        return "Version not available"
    }
}

struct AppStrings
{
    static let copyright = "© 2026 Silver Pine Software, LLC."
    
    static let welcomeMessage =
"""
Welcome to the UUSwiftNetworking sample application!

Use the menu option in the upper left to explore the different samples.

We hope you enjoy it!
"""
    
    static let noteFromTheDevsSectionTitle = "A note from the devs"
    
    static let noteFromTheDevs =
"""
UUSwiftNetworking is a thin, lightweight wrapper around Apple’s built-in URLSession. 

We built it to stay out of your way: no heavy abstraction layer, no reinvented HTTP stack—just a clean, extensible surface on top of the APIs Apple already ships.

We had two goals in mind. 

First, give Swift apps a fast, reliable networking layer that’s easy to drop in and easy to trust in production. 

Second, serve as a readable reference for how to use Apple’s networking APIs well—asynchronous requests, structured errors, pluggable parsers and response handlers, and patterns that scale as your app grows.

This sample app walks through those ideas in practice. 

Whether you adopt the library as-is or borrow pieces for your own stack, we hope it saves you time and helps you build something solid.

Thank you for using UUSwiftNetworking!
"""
}
