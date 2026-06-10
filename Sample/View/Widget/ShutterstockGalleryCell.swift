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

    var body: some View
    {
        GeometryReader
        { geo in
            Group
            {
                if let image
                {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                else
                {
                    Color(.cardBackground)
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .clipped()
        }
        .task(id: url)
        {
            image = await UURemoteImage.shared.image(for: url)
            { remoteImage, error in
            
                if let img = remoteImage
                {
                    DispatchQueue.main.async
                    {
                        self.image = img
                    }
                }
            }
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
