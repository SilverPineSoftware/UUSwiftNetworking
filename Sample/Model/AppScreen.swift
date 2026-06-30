//
//  AppScreen.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/2/26.
//

import SwiftUI

enum AppScreen: CaseIterable, CustomStringConvertible, Identifiable, Hashable
{
    var id: Self { self }
    
    case home
    case account
    case shutterstock
    case openAi
    case about
    
    var description: String
    {
        switch self
        {
            case .home:
                return "Home"
            
            case .account:
                return "Account"
            
            case .shutterstock:
                return "Shutterstock"
            
            case .openAi:       
                return "Open AI"
            
            case .about:
                return "About"
        }
    }
}
