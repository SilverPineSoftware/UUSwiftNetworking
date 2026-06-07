//
//  UUMenuView.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import SwiftUI

private func MenuButton(_ title: String, action: @escaping () -> Void) -> some View
{
    Button(action: action)
    {
        Text(title)
            .font(.uuHeading1)
            .foregroundColor(.primary)
            .padding(.vertical, 4)
    }
}

struct MenuView: View
{
    @ObservedObject var menuViewModel: MenuViewModel
    
    var body: some View
    {
        HStack
        {
            VStack(alignment: .leading)
            {
                Spacer()
                ForEach(menuViewModel.screens)
                { screen in
                    
                    MenuButton(screen.description)
                    {
                        menuViewModel.goto(screen)
                    }
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                }
                
                Spacer()
                
                Text(formatVersionString())
                    .font(.subheadline)
                    .uuCenteredFullWidthStyle()
                    .listRowSeparator(.hidden)
                    .listRowBackground(EmptyView().background(.clear))
                
                Text(AppStrings.copyright)
                    .font(.subheadline)
                    .uuCenteredFullWidthStyle()
                    .listRowSeparator(.hidden)
                    .listRowBackground(EmptyView().background(.clear))
            }
            
            .frame(maxHeight: .infinity)
            .containerRelativeFrame(.horizontal) { width, _ in width * 0.7 }
            .background(.cardBackground)
            
            Spacer()
        }
        .onTapGesture
        {
            withAnimation(.easeInOut)
            {
                menuViewModel.hide()
            }
        }
    }
}


#Preview
{
    let menu = MenuViewModel(screens: AppScreen.allCases, initialScreen: AppScreen.allCases.first!)
    
    ZStack
    {
        Rectangle()
            .ignoresSafeArea()
        
        MenuView(menuViewModel: menu)
    }
}
