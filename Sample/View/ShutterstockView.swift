//
//  ShutterstockView.swift
//  UUSwiftNetworking
//
//  Created by Ryan DeVore on 3/9/26.
//

import SwiftUI

struct ShutterstockView: View
{
    @StateObject private var viewModel = ShutterstockViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View
    {
        VStack(spacing: 0)
        {
            MenuHeaderView(AppScreen.shutterstock)
            {
                Button(action:
                {
                    withAnimation
                    {
                        viewModel.showConfig = true
                    }
                })
                {
                    Image(systemName: "gearshape")
                        .tint(.textBody)
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 15))
                }
                .buttonStyle(.plain)
            }

            searchBar

            ScrollView
            {
                LazyVGrid(columns: columns, spacing: 2)
                {
                    ForEach(Array(viewModel.imageUrls.enumerated()), id: \.offset)
                    { index, url in
                        ShutterstockGalleryCell(url: url)
                            .aspectRatio(1, contentMode: .fit)
                            .onAppear
                            {
                                Task { await viewModel.loadNextPageIfNeeded(currentIndex: index) }
                            }
                    }
                }
                .padding(2)

                if viewModel.isLoading
                {
                    ProgressView()
                        .padding()
                }
            }
            .refreshable
            {
                Task
                {
                    await viewModel.search()
                }
            }
        }
        .background(.appBackground)
        .sheet(isPresented: $viewModel.showConfig)
        {
            ShutterstockConfigView(viewModel: viewModel)
        }
        .task
        {
            if viewModel.imageUrls.isEmpty
            {
                Task
                {
                    await viewModel.search()
                }
            }
        }
    }

    private var searchBar: some View
    {
        TextField("Search images", text: $viewModel.searchQuery)
            .padding(10)
            .background(Color(.cardBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.cardBackgroundBorder), lineWidth: 1)
            )
            .foregroundColor(.textBody)
            .padding(.horizontal, hPadding)
            .padding(.vertical, 8)
            .submitLabel(.search)
            .onSubmit
            {
                Task { await viewModel.search() }
            }
    }
}

#if DEBUG

#Preview
{
    ShutterstockView()
        .environmentObject(MenuViewModel())
}

#endif
