//
//  CircleButton.swift
//  UUBluetooth
//
//  Created by Ryan DeVore on 12/13/24.
//

import UIKit
import SwiftUI

func CircleButton(_ iconName: String, _ action: (() -> Void)? = nil) -> some View
{
    return CircleButton(Image(iconName), action)
}

func CircleButton(systemImage: String, _ action: (() -> Void)? = nil) -> some View
{
    return CircleButton(Image(systemName: systemImage), action)
}

fileprivate func CircleButton(_ image: Image, _ action: (() -> Void)? = nil) -> some View
{
    return ZStack
    {
        Image("button_background")
            .resizable()
            .frame(width: 40, height: 40)
        
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .foregroundColor(.textBody)
    }
    .uuConditionalOnTapGesture(action)
}

extension View
{
    func uuConditionalOnTapGesture(_ action: (() -> Void)?) -> some View
    {
        Group
        {
            if let action = action
            {
                self.onTapGesture(perform: action)
            }
            else
            {
                self
            }
        }
    }
}


#if DEBUG

#Preview
{
    VStack
    {
        CircleButton("play")
        
        CircleButton(systemImage: "line.3.horizontal")
    }
}

#endif
