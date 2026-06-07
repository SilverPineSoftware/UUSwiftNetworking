//
//  AppFonts.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import SwiftUI

public struct AppFonts
{
//    static var h1: Font
//    {
//        return heading(size: 40, weight: .light)
//    }
//    
//    static var h2: Font
//    {
//        return heading(size: 36, weight: .light)
//    }
//    
//    static var h3: Font
//    {
//        return heading(size: 32, weight: .light)
//    }
//
    
    
    
    static func h3(size: CGFloat, weight: Font.Weight = .light) -> Font
    {
        //.system(size: size, weight: weight)
        .largeTitle
    }
    
//    static func heading(size: CGFloat, weight: Font.Weight) -> Font
//    {
//        .system(size: size, weight: weight)
//    }

//    static func label(size: CGFloat) -> Font
//    {
//        .system(size: size, weight: .regular, design: .monospaced)
//    }

//    static func body(size: CGFloat) -> Font
//    {
//        .system(size: size, weight: .bold, design: .monospaced)
//    }

    static func h3uiFont(size: CGFloat) -> UIFont
    {
        //.systemFont(ofSize: size, weight: .ultraLight) // ~200 ExtraLight
        UIFont.preferredFont(forTextStyle: .largeTitle)
    }

//    static func bodyUiFont(size: CGFloat) -> UIFont
//    {
//        .monospacedSystemFont(ofSize: size, weight: .medium)
//    }
}

extension Font
{
    static var uuHeading1: Font
    {
        .largeTitle
        .weight(.light)
    }
    
    static var uuBody: Font
    {
        .body
        .weight(.bold)
        .monospaced()
    }
}
