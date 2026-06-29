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
                
                ActionButton("Silverpine SSO")
                {
                    Task
                    {
                        await viewModel.ssoLogin()
                    }
                }
                
                ActionButton("Test Redirect - No CSP")
                {
                    Task
                    {
                        await viewModel.ssoLogin_test()
                    }
                }
                
                ActionButton("Test Redirect - Broken CSP")
                {
                    Task
                    {
                        await viewModel.ssoLogin_test("1")
                    }
                }
                
                ActionButton("Test Redirect - Dynamic CSP")
                {
                    Task
                    {
                        await viewModel.ssoLogin_test("2")
                    }
                }
                
                ActionButton("Test Redirect - csp 3")
                {
                    Task
                    {
                        await viewModel.ssoLogin_test("3")
                    }
                }
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
