//
//  AppStyling.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import UIKit
import SwiftUI

let hPadding = 15.0
let vPadding = 4.0

struct AppStyling
{
    static let stackSpacing: CGFloat = 4
    
}

/*
public struct AppStyling
{
    static let stackSpacing: CGFloat = 4

    static func apply()
    {
        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [.font: AppFonts.h3uiFont(size: 40), .foregroundColor: Color.textLabel]
        appearance.titleTextAttributes = [.font: AppFonts.h3uiFont(size: 22), .foregroundColor: Color.textLabel]
        appearance.shadowColor = nil
        appearance.backgroundColor = UIColor(.appBackground)
        
        let navBarAppearance = UINavigationBar.appearance()
        navBarAppearance.standardAppearance = appearance
        navBarAppearance.scrollEdgeAppearance = appearance
    }
}*/


extension View
{
    /*func applyScreenTitleStyle() -> some View
    {
        return self.font(AppFonts.h3(size: 40))
            .foregroundColor(.textLabel)
            .padding(EdgeInsets(top: 0, leading: hPadding, bottom: 0, trailing: hPadding))
            .applyLeadingFullWidthStyle()
    }
    
    func applySingleLineScreenTitleStyle(fontSize: CGFloat = 40, minimumScaleFactor: CGFloat = 0.7) -> some View
    {
        return self.font(AppFonts.h3(size: fontSize))
            .foregroundColor(.textLabel)
            .padding(EdgeInsets(top: 0, leading: hPadding, bottom: 0, trailing: hPadding))
            .applyLeadingFullWidthStyle()
            .lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
    }
    
    func applyMenuOptionStyle() -> some View
    {
        return self.font(AppFonts.h3(size: 40, weight: .light))
            .foregroundColor(.textLabel)
            .padding(EdgeInsets(top: 0, leading: hPadding, bottom: 0, trailing: hPadding))
            .applyLeadingFullWidthStyle()
    }*/
    
    func applyCardStyle() -> some View
    {
        return self.background(.clear)
            .padding(EdgeInsets(top: 24, leading: 15, bottom: 24, trailing: 15))
            .background(RoundedRectangle(cornerRadius: 4)
                .fill(.cardBackground)
                .stroke(.cardBackgroundBorder, lineWidth: 1)
                .background(.clear))
            .listRowSeparator(.hidden)
            .listRowBackground(EmptyView().background(.clear))
    }
    
    func applyListStyle() -> some View
    {
        return self.listStyle(.plain)
            .listRowSeparator(.hidden)
            .background(.appBackground)
            .scrollContentBackground(.hidden)
            .navigationBarBackButtonHidden(true)
    }
    
    func applyLabelValueStyle() -> some View
    {
        return self.padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(.appBackground)
            )
    }
    
//    func applyLeadingFullWidthStyle() -> some View
//    {
//        return self.frame(maxWidth: .infinity, alignment: .leading)
//            .multilineTextAlignment(.leading)
//    }
    
    /*func applyLabelTextStyle(_ fontSize: CGFloat) -> some View
    {
        return self.font(.title2) //   AppFonts.label(size: fontSize))
            .foregroundColor(.textLabel)
            .applyLeadingFullWidthStyle()
    }
    
    func applyBodyTextStyle(_ fontSize: CGFloat) -> some View
    {
        return self.font(
                .body
                .weight(.bold)
                .monospaced())
        .foregroundColor(.secondary)
            //.foregroundColor(.textBody)
            .applyLeadingFullWidthStyle()
    }
    
    func applyLinkTextStyle(_ fontSize: CGFloat) -> some View
    {
        return self.font(.uuBody)
            .foregroundColor(.textLink)
            .applyLeadingFullWidthStyle()
    }*/
    
    func applySectionHeaderStyle(_ fontSize: CGFloat = 20) -> some View
    {
        return self.font(.title2)
            .foregroundColor(.headerLabel)
            .uuLeadingFullWidthStyle()
    }
    
    /*
    func applySingleLineBodyTextStyle(_ fontSize: CGFloat, minimumScaleFactor: CGFloat = 0.7) -> some View
    {
        return self.font(.uuBody)
            .foregroundColor(.textBody)
            .applyLeadingFullWidthStyle()
            .lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
    }*/
    
    func applyButtonTextStyle(_ fontSize: CGFloat) -> some View
    {
        return self.font(.uuBody)
            .foregroundColor(.textBody)
    }
}

extension View
{
    func uuLeadingFullWidthStyle() -> some View
    {
        return self.frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }
    
    func uuCenteredFullWidthStyle() -> some View
    {
        return self.frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }
    
    func uuTrailingFullWidthStyle() -> some View
    {
        return self.frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
    }
    
    func uuSingleLineStyle(minimumScaleFactor: CGFloat = 0.7) -> some View
    {
        return self.lineLimit(1)
            .minimumScaleFactor(minimumScaleFactor)
    }
    
    func uuScreenTitleSytle() -> some View
    {
        return self.font(.uuHeading1)
            .foregroundColor(.textLabel)
            .padding(EdgeInsets(top: 0, leading: hPadding, bottom: 0, trailing: hPadding))
            .uuLeadingFullWidthStyle()
    }
    
    func uuBodyStyle() -> some View
    {
        return self.font(.uuBody)
        .foregroundColor(.secondary)
            .uuLeadingFullWidthStyle()
    }
}

#Preview("Swift UI Text Styles")
{
    ScrollView
    {
        Spacer(minLength: 40)
        
        VStack
        {
            Text("Large Title")
                .font(.largeTitle)
            
            Divider()
            
            Text("Title")
                .font(.title)
            
            Divider()
            
            Text("Title 2")
                .font(.title2)
            
            Divider()
            
            Text("Title 3")
                .font(.title3)
            
            Divider()
            
            Text("Headline")
                .font(.headline)
            
            Divider()
            
            Text("Sub Headline")
                .font(.subheadline)
            
            Divider()
            
            Text("Caption")
                .font(.caption)
            
            Divider()
            
            Text("Caption 2")
                .font(.caption2)
            Divider()
            
            Text("Footnote")
                .font(.footnote)
            
            Divider()
            
            Text("Body")
                .font(.body)
                //.bold()
                //.monospaced()
                .foregroundColor(.secondary)
            
            Text("uuBodyStyle")
                .uuBodyStyle()
            
            Divider()
            
            Text("Callout")
                .font(.callout)
            
            Divider()
            
            //Text("Default")
            //    .font(.default)
        }
    }
}
