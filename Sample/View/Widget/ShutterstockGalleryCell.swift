//
//  ShutterstockGalleryCell.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/9/26.
//

import SwiftUI
import UUSwiftNetworking

struct ShutterstockGalleryCell: View
{
    let url: String
    @State private var image: UUImage?
    @State private var isLoading = false
    @State private var imageOpacity: Double = 0
    @State private var placeholderOpacity: Double = 1.0

    private var placeholder: some View
    {
        ZStack
        {
            Color(.cardBackground)
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: isLoading && image == nil)
        }
    }
    
    var body: some View
    {
        GeometryReader
        { geo in
            Group
            {
                placeholder
                
                if let image
                {
                    Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .opacity(imageOpacity)
                            .onAppear
                            {
                                withAnimation(.easeIn(duration: 0.25))
                                {
                                    imageOpacity = 1
                                }
                            }
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .clipped()
        }
        .task(id: url)
        {
            isLoading = true
            image = await UURemoteImage.shared.image(for: url)
            { remoteImage, error in
            
                if let img = remoteImage
                {
                    DispatchQueue.main.async
                    {
                        isLoading = false
                        self.image = img
                    }
                }
            }
            
            isLoading = (image == nil)
        }
    }
}

#if DEBUG

#Preview
{
    ShutterstockGalleryCell(url: "https://example.com/image.jpg")
        .aspectRatio(1, contentMode: .fit)
        .frame(width: 120)
}

#endif
