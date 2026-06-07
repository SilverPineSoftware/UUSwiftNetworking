//
//  HeaderView.swift
//  Silvertooth
//
//  Created by Ryan DeVore on 12/23/24.
//

import SwiftUI

struct MenuHeaderView<RightView: View>: View
{
    var title: String
    @EnvironmentObject var menuViewModel: MenuViewModel
    let rightView: RightView
    
    init(title: String,
         @ViewBuilder rightView: () -> RightView = { EmptyView() })
    {
        self.title = title
        self.rightView = rightView()
    }
    
    init(_ screen: AppScreen,
         @ViewBuilder rightView: () -> RightView = { EmptyView() })
    {
        self.title = screen.description
        self.rightView = rightView()
    }
    
    var body: some View
    {
        
        VStack
        {
            HStack
            {
                ImageButton(systemImage: "line.3.horizontal", width: 24, height: 24)
                {
                    withAnimation(.easeInOut)
                    {
                        menuViewModel.show()
                        
                    }
                }
                .padding(EdgeInsets(top: vPadding, leading: hPadding, bottom: vPadding, trailing: 0))
                
                Spacer()
                
                rightView
            }
            .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
            
             Text(title.uppercased())
                .uuScreenTitleSytle()
        }
        //.background(.appBackground)
    }
}

#Preview
{
    VStack
    {
        MenuHeaderView(title: "Screen Title")
        Spacer()
        
        /*
        ImageButton(systemImage: "line.3.horizontal")
        {
        }
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
        
        ImageButton(systemImage: "line.horizontal.3")
        {
        }
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
        
        ImageButton(systemImage: "line.3.horizontal.circle")
        {
        }
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
        
        ImageButton(systemImage: "line.3.horizontal.circle.fill")
        {
        }
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
        
        CircleButton(systemImage: "line.3.horizontal")
        {
        }
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
        
        CircleButton(systemImage: "line.horizontal.3")
        {
        }
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
        
        CircleButton(systemImage: "line.3.horizontal.decrease")
        {
        }
        .padding(EdgeInsets(top: 0, leading: 15, bottom: 8, trailing: 15))
        */
        
    }
    .background(.appBackground)
}
