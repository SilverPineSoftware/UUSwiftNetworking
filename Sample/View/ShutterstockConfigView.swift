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
                SettingsGroup("Credentials")
                {
                    VStack
                    {
                        HStack
                        {
                            Text("Client Key")
                                .font(.body.monospaced())
                            
                            Spacer()
                        }
                        
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
                    }
                    
                    VStack
                    {
                        HStack
                        {
                            Text("Client Secret")
                                .font(.body.monospaced())
                            
                            Spacer()
                        }
                        
                        SecureField("Client Secret", text: $viewModel.clientSecret)
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
                    
                    if let credentialsError = viewModel.credentialsError
                    {
                        Text(credentialsError)
                            .font(.footnote.monospaced())
                            .foregroundColor(.red)
                    }
                    
                    HStack
                    {
                        Button("Clear")
                        {
                            Task
                            {
                                await viewModel.clearCredentials()
                            }
                        }
                        
                        Spacer()
                        
                        Button("Save")
                        {
                            Task
                            {
                                await viewModel.saveCredentials()
                            }
                        }
                    }
                }
                
                SettingsGroup("Config")
                {
                    VStack
                    {
                        HStack
                        {
                            Text("Records per page")
                                .font(.body.monospaced())
                            
                            Spacer()
                        }
                        
                        TextField("number", value: $viewModel.perPage, format: .number)
                            .padding(10)
                            .background(Color(.cardBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.cardBackgroundBorder), lineWidth: 1)
                            )
                            .keyboardType(.numberPad)
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
        .task
        {
            await viewModel.loadCredentials()
        }
    }
}



#if DEBUG

#Preview
{
    ShutterstockConfigView(viewModel: ShutterstockViewModel())
}

#endif
