//
//  SettingsGroup.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/9/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import SwiftUI

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
