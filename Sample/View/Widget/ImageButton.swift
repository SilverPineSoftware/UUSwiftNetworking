//
//  ImageButton.swift
//  UUBluetooth
//
//  Created by Ryan DeVore on 12/13/24.
//

import UIKit
import SwiftUI

func ImageButton(systemImage: String, width: CGFloat = 40, height: CGFloat = 40, _ action: (() -> Void)? = nil) -> some View
{
    Button(action:
    {
        withAnimation
        {
            action?()
        }
    })
    {
        Image(systemName: systemImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .foregroundColor(.textBody)
            
    }
    .buttonStyle(.plain)
}

#if DEBUG

#Preview
{
    VStack
    {
        ImageButton(systemImage: "line.3.horizontal")
    }
}

#endif
