//
//  RootView.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import SwiftUI
import SwiftData
import UUSwiftCore

struct RootView: View
{
    @EnvironmentObject var menuViewModel: MenuViewModel
    @EnvironmentObject var accountViewModel: AccountViewModel
    
    var body: some View
    {
        NavigationStack
        {
            ZStack
            {
                switch (menuViewModel.currentScreen)
                {
                    case .home:
                        HomeView()
                            .zIndex(0)
                
                    case .account:
                    AccountView(viewModel: accountViewModel)
                            .zIndex(0)
                    
                    case .shutterstock:
                        ShutterstockView()
                            .zIndex(0)
                        
                    case .openAi:
                        OpenAiView()
                            .zIndex(0)
                    
                    case .about:
                        AboutView()
                            .zIndex(0)
                }
                
                if menuViewModel.isMenuDimmerVisible
                {
                    Color.fullScreenDim.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                        .zIndex(1) // Ensure it's above the content but below the menu
                        .onTapGesture
                    {
                        menuViewModel.hide()
                    }
                }
                
                if menuViewModel.isMenuVisible
                {
                    MenuView(menuViewModel: menuViewModel)
                        .offset(x: menuViewModel.isMenuVisible ? 0 : -UIScreen.main.bounds.width)
                        .transition(.move(edge: .leading))
                        .zIndex(2) // Ensure the menu is above the main content
                }
            }
        }
        .background(.appBackground)
    }
}

#if DEBUG

#Preview
{
    RootView()
        .environmentObject(MenuViewModel())
}

#endif
