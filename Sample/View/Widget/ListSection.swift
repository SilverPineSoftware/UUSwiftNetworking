//
//  ListSection.swift
//  UUBluetooth
//
//  Created by Ryan DeVore on 12/14/24.
//

import SwiftUI

struct SectionTitle: View
{
    var title: String
    
    init(_ title: String)
    {
        self.title = title
    }
    
    var body: some View
    {
        Text(title)
            .applySectionHeaderStyle()
    }
}

func ListSection<Header: View, Content: View, Footer: View>(
    @ViewBuilder header: () -> Header = { EmptyView() },
    @ViewBuilder content: () -> Content,
    @ViewBuilder footer: () -> Footer = { EmptyView() }) -> some View
{
    VStack(spacing: AppStyling.stackSpacing)
    {
        header()
        content()
        footer()
    }
    .applyCardStyle()
}

func ListSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View
{
    ListSection(header: { SectionTitle(title) }, content: content)
}

/*
func SettingsGroup<Content: View, Footer: View>(
    _ title: String,
    @ViewBuilder content: () -> Content,
    @ViewBuilder footer: () -> Footer = { EmptyView() }) -> some View
{
    VStack
    {
        SectionTitle(title)
          
        VStack(spacing: AppStyling.stackSpacing)
        {
            content()
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.appBackground)
                )
        }
        
        footer()
    }
    .applyCardStyle()
}
*/
