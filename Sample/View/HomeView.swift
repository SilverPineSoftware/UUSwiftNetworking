//
//  HomeView.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import SwiftUI

struct HomeView: View
{
    var body: some View
    {
        VStack(spacing: 0)
        {
            MenuHeaderView(title: "Networking Sample")
            //MenuHeaderView(AppScreen.home)
            
            ScrollView
            {
                Text(AppStrings.welcomeMessage)
                .uuBodyStyle()
                .padding(hPadding)
                Spacer()
            }
        }
        .background(.appBackground)
    }
}

#Preview
{
    HomeView()
}
