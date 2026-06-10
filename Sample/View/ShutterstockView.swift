//
//  ShutterstockView.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 3/9/26.
//

import SwiftUI
import Combine

struct ShutterstockView: View
{
    @ObservedObject var viewModel: ShutterstockViewModel = ShutterstockViewModel()
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            MenuHeaderView(AppScreen.shutterstock)
            {
                Button(action:
                {
                    withAnimation
                    {
                        viewModel.showConfig = true
                    }
                })
                {
                    Image(systemName: "gearshape")
                        .tint(.textBody)
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 15))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .background(.appBackground)
        
        .sheet(isPresented: $viewModel.showConfig)
        {
            ShutterstockConfigView(viewModel: viewModel)
        }
    }
}



#if DEBUG

#Preview
{
    ShutterstockView()
}

#endif
