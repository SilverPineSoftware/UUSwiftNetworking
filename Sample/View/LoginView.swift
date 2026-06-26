//
//  LoginView.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/25/26.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View
{
    //@Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @ObservedObject var viewModel: LoginViewModel
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            MenuHeaderView(title: "Login")
            
            List
            {
                Text(AppStrings.notLoggedInMessage)
                    .uuBodyStyle()
                    .padding(hPadding)
                    .applyListItemStyle()
                
                Button
                {
                    Task
                    {
                        await viewModel.ssoLogin() //webAuthenticationSession)
                    }
                }
                label:
                {
                    Text("Silverpine SSO")
                        .applyButtonTextStyle(14)
                        .padding()
                }
                .buttonStyle(.plain)
                .background {
                    Capsule()
                        .fill(.cardBackground)
                }
                .applyListItemStyle()
                .frame(maxWidth: .infinity, alignment: .center)
                
            }
            .applyListStyle()
        }
        .background(.appBackground)
    }
}

#Preview
{
    LoginView(viewModel: LoginViewModel())
}
