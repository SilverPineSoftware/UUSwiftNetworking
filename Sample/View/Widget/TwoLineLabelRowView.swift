
//
//  TwoLineLabelRowView.swift
//  BluetoothExplorer
//
//  Created by Ryan DeVore on 11/11/24.
//

import SwiftUI

func TwoLineLabelRowView<BodyView: View>(
    _ label: String,
    @ViewBuilder body: () -> BodyView) -> some View
{
    return VStack
    {
        Text(label.uppercased())
            .applyLabelTextStyle(12)
        
        body()
    }
    .applyLabelValueStyle()
}

func TwoLineLabelRowView(
    label: String,
    value: String,
    valueIcon: String? = nil,
    valueSingleLine: Bool = false) -> some View
{
    return TwoLineLabelRowView(label)
    {
        HStack
        {
            if let img = valueIcon
            {
                Image(img)
            }
            
            if (valueSingleLine)
            {
                Text(value)
                    .applySingleLineBodyTextStyle(18)
            }
            else
            {
                Text(value)
                    .applyBodyTextStyle(18)
            }
        }
    }
}

func IDRowView(_ uuid: String) -> some View
{
    return TwoLineLabelRowView("ID")
    {
        Text(uuid)
            .applySingleLineBodyTextStyle(18)
    }
}

#Preview
{
    VStack {
        
        TwoLineLabelRowView(label: "Foo", value: "Bar")
        TwoLineLabelRowView(label: "Foo", value: ["Red", "White", "Blue"].joined(separator: "\n"))
        
        TwoLineLabelRowView(label: "Timestamp", value: Date().description, valueIcon: "timestamp")
        
        HStack {
            TwoLineLabelRowView(label: "Connectable", value: "True")
            TwoLineLabelRowView(label: "Primary Phy", value: "129")
            TwoLineLabelRowView(label: "Secondary Phy", value: "0")
        }
        
    }
}
