//
//  MenuViewModel.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import SwiftUI
import Combine

class MenuViewModel: ObservableObject
{
    @Published public var isMenuDimmerVisible = false
    @Published public var isMenuVisible = false
    @Published public var currentScreen: AppScreen
    
    public private(set) var screens: [AppScreen]
    
    public init(screens: [AppScreen] = AppScreen.allCases, initialScreen: AppScreen = .home)
    {
        self.screens = screens
        self.currentScreen = initialScreen
    }
    
    public func goto(_ screen: AppScreen)
    {
        currentScreen = screen
        hide()
    }
    
    public func show()
    {
        withAnimation
        {
            isMenuDimmerVisible = true // Dim the background first
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
        {
            withAnimation
            {
                self.isMenuVisible = true // Then slide out the menu
            }
        }
    }
    
    public func hide()
    {
        withAnimation
        {
            isMenuVisible = false // Slide the menu back first
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
        {
            withAnimation
            {
                self.isMenuDimmerVisible = false // Remove the dimmed background
            }
        }
    }
}
