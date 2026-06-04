
//
//  OpenAiView.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import SwiftUI

struct OpenAiView: View
{
    var body: some View
    {
        VStack(spacing: 0)
        {
            MenuHeaderView(AppScreen.openAi)
            Spacer()
        }
        .background(.appBackground)
    }
}



#if DEBUG


#Preview
{
    OpenAiView()
}

#endif
