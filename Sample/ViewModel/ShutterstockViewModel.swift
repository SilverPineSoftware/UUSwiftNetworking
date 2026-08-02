//
//  ShutterstockViewModel.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/9/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import Combine
import UUSwiftNetworking

@MainActor
class ShutterstockViewModel: ObservableObject
{
    @Published var showConfig: Bool = false
    @Published var searchQuery: String = "labrador"
    @Published var imageUrls: [String] = []
    @Published var isLoading: Bool = false

    @Published var clientKey: String = ""
    @Published var clientSecret: String = ""
    @Published var credentialsError: String?
    @Published var perPage: Int = 20

    private var api: ShutterstockApi = AppServices.shutterstockServer
    private var currentPage: Int = 0
    private var hasMore: Bool = true
    //private let perPage: Int = 20

    init()
    {

    }
    
    func loadCredentials() async
    {
        switch await api.loadCredentials()
        {
            case .failure(let error):
                credentialsError = "\(error)"
            
            case .success(let credentials):
                clientKey = credentials.clientKey
                clientSecret = credentials.clientSecret
                credentialsError = nil
        }
    }
    
    func saveCredentials() async
    {
        let credentials = ShutterstockCredentials(
            clientKey: clientKey,
            clientSecret: clientSecret)
        
        if let error = await api.saveCredentials(credentials)
        {
            credentialsError = "\(error)"
        }
        else
        {
            credentialsError = nil
        }
    }
    
    func clearCredentials() async
    {
        if let error = await api.clearCredentials()
        {
            credentialsError = "\(error)"
        }
        else
        {
            clientKey = ""
            clientSecret = ""
            credentialsError = nil
        }
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
