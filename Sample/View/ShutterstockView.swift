//
//  HomeView.swift
//  BluetoothExplorer
//
//  Created by Ryan DeVore on 11/2/24.
//

import SwiftUI

struct ShutterstockView: View
{
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            MenuHeaderView(AppScreen.shutterstock)
            Spacer()
        }
        .background(.appBackground)
    }
}



#if DEBUG

#Preview
{
    ShutterstockView()
}

#endif
