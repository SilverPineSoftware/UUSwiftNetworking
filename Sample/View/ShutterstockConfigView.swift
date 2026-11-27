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

    @State private var savedClientKey: String = ""
    @State private var savedClientSecret: String = ""
    @State private var didLoadCredentials: Bool = false
    @State private var showDiscardConfirmation: Bool = false
    @State private var showClearConfirmation: Bool = false

    private var hasUnsavedChanges: Bool
    {
        didLoadCredentials &&
        (viewModel.clientKey != savedClientKey || viewModel.clientSecret != savedClientSecret)
    }
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            HStack
            {
                Spacer()
                
                Button(action:
                {
                    if hasUnsavedChanges
                    {
                        showDiscardConfirmation = true
                    }
                    else
                    {
                        closeConfig()
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
                            .textContentType(.oneTimeCode)
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
                            showClearConfirmation = true
                        }
                        
                        Spacer()
                        
                        Button("Save")
                        {
                            Task
                            {
                                await viewModel.saveCredentials()

                                if viewModel.credentialsError == nil
                                {
                                    updateSavedCredentials()
                                }
                            }
                        }
                        .disabled(!hasUnsavedChanges)
                    }
                    .buttonStyle(.borderless)
                }
                footer:
                {
                    if hasUnsavedChanges
                    {
                        Label("Unsaved changes", systemImage: "exclamationmark.circle.fill")
                            .font(.footnote.monospaced())
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .alert("Unsaved Changes", isPresented: $showDiscardConfirmation)
        {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard Changes", role: .destructive)
            {
                viewModel.clientKey = savedClientKey
                viewModel.clientSecret = savedClientSecret
                closeConfig()
            }
        }
        message:
        {
            Text("Your Shutterstock credentials have unsaved changes. Are you sure you want to abandon them?")
        }
        .alert("Clear Credentials?", isPresented: $showClearConfirmation)
        {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive)
            {
                Task
                {
                    await viewModel.clearCredentials()

                    if viewModel.credentialsError == nil
                    {
                        updateSavedCredentials()
                    }
                }
            }
        }
        message:
        {
            Text("This will permanently remove the saved Shutterstock client key and secret.")
        }
        .task
        {
            await viewModel.loadCredentials()
            updateSavedCredentials()
            didLoadCredentials = true
        }
    }

    private func updateSavedCredentials()
    {
        savedClientKey = viewModel.clientKey
        savedClientSecret = viewModel.clientSecret
    }

    private func closeConfig()
    {
        withAnimation
        {
            viewModel.showConfig = false
        }
    }
}



#if DEBUG

#Preview
{
    ShutterstockConfigView(viewModel: ShutterstockViewModel())
}

#endif
