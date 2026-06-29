//
//  ActionButton.swift
//  Sample
//
//  Created by Ryan DeVore on 6/29/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import SwiftUI


func ActionButton(_ label: String, _ action: @escaping () -> Void) -> some View
{
    Button
    {
        action()
    }
    label:
    {
        Text(label)
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
