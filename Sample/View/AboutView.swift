//
//  AboutView.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import SwiftUI
import UUSwiftCore

struct AboutView: View
{
    var body: some View
    {
        VStack(spacing: 0)
        {
            MenuHeaderView(AppScreen.about)
            
            List
            {
                SettingsGroup(AppStrings.noteFromTheDevsSectionTitle)
                {
                    Text(AppStrings.noteFromTheDevs)
                    .uuBodyStyle()
                }
            }
            .applyListStyle()
            
            
        }
        .background(.appBackground)
    }
}

#Preview
{
    AboutView()
}
