//
//  AccountView.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/25/26.
//

import SwiftUI
import AuthenticationServices

struct AccountView: View
{
    //@Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @ObservedObject var viewModel: AccountViewModel
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            MenuHeaderView(title: "Account")
            
            List
            {
                if let u = viewModel.user
                {
                    ListSection("Me")
                    {
                        TwoLineLabelRowView(label: "ID", value: u.id)
                        TwoLineLabelRowView(label: "Email", value: u.email)
                        TwoLineLabelRowView(label: "Display Name", value: u.displayName)
                        TwoLineLabelRowView(label: "Role", value: u.role)
                        TwoLineLabelRowView(label: "Is Super User", value: u.isSuperUser ? "Yes" : "No")
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

#Preview("Not Logged In")
{
    let api = MockNetworkingApi()
    let vm = AccountViewModel(api: api)
    AccountView(viewModel: vm)
}

#Preview("Logged In")
{
    let vm: AccountViewModel = {
        let api = MockNetworkingApi()
        api.getMeResult = .success(
            AppServerDTO.User(
                id: "fake-id",
                email: "fake@mocked.com",
                displayName: "Mock User",
                role: "normal",
                isSuperUser: false
            )
        )

        return AccountViewModel(api: api)
    }()
    
    AccountView(viewModel: vm)
}
