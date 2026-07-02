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
                
                /*ActionButton("Login - Link")
                {
                    Task
                    {
                        await viewModel.magicLinkLogin()
                    }
                }*/
            }
            .applyListStyle()
        }
        .background(.appBackground)
    }
}

#Preview
{
    AccountView(viewModel: AccountViewModel())
}
