//
//  AccountView.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/25/26.
//

import SwiftUI
import AuthenticationServices
import UUSwiftCore

struct AccountView: View
{
    //@Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @ObservedObject var viewModel: AccountViewModel
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            MenuHeaderView(title: "Account")
            {
                Menu
                {
                    if (viewModel.isLoggedIn)
                    {
                        Button
                        {
                            Task
                            {
                                await viewModel.refresh()
                            }
                        }
                        label:
                        {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }

                        Divider()
                        
                        Button(role: .destructive)
                        {
                            Task
                            {
                                await viewModel.ssoLogout()
                            }
                        }
                        label:
                        {
                            Label("Logout", systemImage: "arrow.uturn.backward")
                        }
                    }
                    else
                    {
                        ActionButton("Login")
                        {
                            Task
                            {
                                await viewModel.ssoLogin()
                            }
                        }
                    }
                }
                label:
                {
                    Image(systemName: "ellipsis")
                }
                .padding(EdgeInsets(top: vPadding, leading: hPadding, bottom: vPadding, trailing: hPadding))
            }
            
            List
            {
                if let e = viewModel.error
                {
                    Text(e.accountErrorText)
                        .uuBodyStyle()
                        .padding(hPadding)
                        .applyListItemStyle()
                }
                else if let u = viewModel.user
                {
                    ListSection("Me")
                    {
                        TwoLineLabelRowView(label: "ID", value: u.id)
                        TwoLineLabelRowView(label: "Email", value: u.email)
                        TwoLineLabelRowView(label: "Display Name", value: u.displayName)
                        TwoLineLabelRowView(label: "Role", value: u.role)
                        TwoLineLabelRowView(label: "Is Super User", value: u.isSuperUser ? "Yes" : "No")
                        TwoLineLabelRowView(label: "Valid Until", value: u.tokenValidUntil.uuFormat("yyyy-MM-dd hh:mm:ss a"))
                    }
                }
                else
                {
                    Text(AppStrings.notLoggedInMessage)
                        .uuBodyStyle()
                        .padding(hPadding)
                        .applyListItemStyle()
                    
                    ActionButton("Login - Direct")
                    {
                        Task
                        {
                            await viewModel.ssoLogin()
                        }
                    }
                }
            }
            .applyListStyle()
            .refreshable
            {
                await viewModel.refresh()
            }
        }
        .background(.appBackground)
        .task
        {
            await viewModel.refresh()
        }
    }
}

fileprivate extension AppError
{
    var accountErrorText: String
    {
        var text = ""
        
        switch (self)
        {
            case .noRefreshToken, .notSignedIn, .stateCheckFailed:
                text += "Unable to fetch the current user. Please use the Login button from the menu to sign in again."
            
            case .invalidConfigUrl, .invalidLoginUrl:
                text += "Please check your AppConfig.json"
            
            case .apiCallFailed(let error):
                text += "An api call to the server failed:\n\n\(error.localizedDescription)"
            
            case .unexpectedError(let msg):
                text += "An unexpected error occurred:\n\n\(msg)"
        }
        
        text += "\n\n\(errorName)"
        
        return text
    }
}

#Preview("Not Logged In")
{
    let vm: AccountViewModel = {
        let api = MockNetworkingApi()
        api.getMeResult = .failure(.notSignedIn)
        
        return AccountViewModel(api: api)
    }()
    
    
    AccountView(viewModel: vm)
}

#Preview("Logged In")
{
    let vm: AccountViewModel = {
        let api = MockNetworkingApi()
        api.getMeResult = .success(
            AppUser(
                id: "fake-id",
                email: "fake@mocked.com",
                displayName: "Mock User",
                role: "normal",
                isSuperUser: false,
                tokenValidUntil: Date()
            )
        )

        return AccountViewModel(api: api)
    }()
    
    AccountView(viewModel: vm)
}
