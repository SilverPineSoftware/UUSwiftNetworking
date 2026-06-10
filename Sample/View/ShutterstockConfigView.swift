//
//  ShutterstockConfigView.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 3/9/26.
//

import SwiftUI

struct ShutterstockConfigView: View
{
    @ObservedObject var viewModel: ShutterstockViewModel
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            HStack
            {
                Spacer()
                
                Button(action:
                {
                    withAnimation
                    {
                        viewModel.showConfig = false
                    }
                })
                {
                    Image(systemName: "xmark")
                        .tint(.textBody)
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 15))
                }
                .buttonStyle(.plain)
                .padding(EdgeInsets(top: 16, leading: 0, bottom: 8, trailing: 0))
            }
            
            Spacer()
            
            List
            {
                SettingsGroup("Shutterstock Config")
                {
                    VStack
                    {
                        TextField("Client Key", text: $viewModel.clientKey)
                            .padding(10)
                            .background(Color(.cardBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.cardBackgroundBorder), lineWidth: 1)
                            )
                            .keyboardType(.default)
                            .autocapitalization(.words)
                            .foregroundColor(.textBody)
                            .font(.body.monospaced())
                        
                        TextField("Client Secret", text: $viewModel.clientSecret)
                            .padding(10)
                            .background(Color(.cardBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.cardBackgroundBorder), lineWidth: 1)
                            )
                            .keyboardType(.default)
                            .autocapitalization(.words)
                            .foregroundColor(.textBody)
                            .font(.body.monospaced())

                    }
                }
            }
            .applyListStyle()
        }
        .safeAreaPadding([.top, .trailing])
        .background(.appBackground)
    }
}



#if DEBUG

#Preview
{
    ShutterstockConfigView(viewModel: ShutterstockViewModel())
}

#endif
