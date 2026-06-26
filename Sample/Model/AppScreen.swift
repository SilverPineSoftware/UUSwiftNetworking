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
    case login
    case shutterstock
    case openAi
    case about
    
    var description: String
    {
        switch self
        {
            case .home:
                return "Home"
            
            case .login:
                return "Login"
            
            case .shutterstock:
                return "Shutterstock"
            
            case .openAi:       
                return "Open AI"
            
            case .about:
                return "About"
        }
    }
}
