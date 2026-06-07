//
//  UUSwiftNetworkingSampleApp.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import SwiftUI

@main
struct SampleApp: App
{
    private let menuViewModel = MenuViewModel()
    
//    init()
//    {
//        AppStyling.apply()
//    }
    
    var body: some Scene
    {
        WindowGroup
        {
            RootView()
                .environmentObject(menuViewModel)
                //.background {
//                                    UUAppColors.background
//                                        .ignoresSafeArea()
//                                }
        }
    }
}
