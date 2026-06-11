//
//  ShutterstockViewModel.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/9/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import Combine

@MainActor
class ShutterstockViewModel: ObservableObject
{
    @Published var showConfig: Bool = false
    @Published var searchQuery: String = "labrador"
    @Published var imageUrls: [String] = []
    @Published var isLoading: Bool = false

    @Published var clientKey: String = ""
    {
        didSet
        {
            var cfg = ShutterstockApiConfig.load()
            cfg.clientKey = clientKey
            cfg.save()

            api.config = cfg
        }
    }

    @Published var clientSecret: String = ""
    {
        didSet
        {
            var cfg = ShutterstockApiConfig.load()
            cfg.clientSecret = clientSecret
            cfg.save()

            api.config = cfg
        }
    }

    private var api: ShutterstockApi = ShutterstockApi()
    private var currentPage: Int = 0
    private var hasMore: Bool = true
    private let perPage: Int = 500

    init()
    {
        let cfg = ShutterstockApiConfig.load()
        clientKey = cfg.clientKey
        clientSecret = cfg.clientSecret
    }

    func search() async
    {
        currentPage = 0
        hasMore = true
        imageUrls.removeAll()
        await loadNextPage()
    }

    func loadNextPageIfNeeded(currentIndex: Int) async
    {
        guard hasMore, !isLoading else { return }
        guard currentIndex >= imageUrls.count - 6 else { return }

        await loadNextPage()
    }

    private func loadNextPage() async
    {
        guard hasMore, !isLoading else { return }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let nextPage = currentPage + 1
        let pageResult = await api.searchImagePage(
            query: query,
            page: nextPage,
            count: perPage,
            large: false)

        switch pageResult
        {
        case .failure(let err):
            NSLog("Fetch image page failed, err: \(err)")

        case .success(let urls):
            if urls.isEmpty
            {
                hasMore = false
            }
            else
            {
                currentPage = nextPage
                imageUrls.append(contentsOf: urls)
                hasMore = urls.count >= perPage
            }
        }
    }
}
