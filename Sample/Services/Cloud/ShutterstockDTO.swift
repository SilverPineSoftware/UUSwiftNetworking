//
//  ShutterstockDTO.swift
//  Sample
//
//  Created by Ryan DeVore on 7/11/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation

enum ShutterstockDTO
{
    // Error object
    struct Error: Codable
    {
        let code: String?
        let data: String?
        // Defined as 'object' in spec. provide custom implementation if needed.
        // let items: [Codable]?
        let message: String
        let path: String?

        enum CodingKeys: String, CodingKey
        {
            case code
            case data
            // Defined as 'object' in spec. provide custom implementation if needed.
            // case items
            case message
            case path
        }
    }

    // Image search results
    struct SearchImagesResponse: Codable
    {
        let data: [GetImageResponse]
        let message: String?
        let page: Int?
        let perPage: Int?
        let searchId: String
        // Defined as 'object' in spec. provide custom implementation if needed.
        // let spellcheckInfo: Codable?
        let totalCount: Int

        enum CodingKeys: String, CodingKey
        {
            case data
            case message
            case page
            case perPage = "per_page"
            case searchId = "search_id"
            // Defined as 'object' in spec. provide custom implementation if needed.
            // case spellcheckInfo = "spellcheck_info"
            case totalCount = "total_count"
        }
    }


    // Information about an image
    struct GetImageResponse: Codable
    {
        let addedDate: String?
        let affiliateUrl: String?
        let aspect: Float?
        let assets: ImageAsset?
        let categories: [Category]?
        let contributor: Contributor
        let description: String?
        let hasModelRelease: Bool?
        let hasPropertyRelease: Bool?
        let id: String
        let imageType: String?
        let isAdult: Bool?
        let isEditorial: Bool?
        let isIllustration: Bool?
        let keywords: [String]?
        let mediaType: String
        let modelReleases: [ModelPropertyRelease]?
        let models: [HumanModelPropertyAppearsMedia]?
        let releases: [String]?
        let url: String?

        enum CodingKeys: String, CodingKey
        {
            case addedDate = "added_date"
            case affiliateUrl = "affiliate_url"
            case aspect
            case assets
            case categories
            case contributor
            case description
            case hasModelRelease = "has_model_release"
            case hasPropertyRelease = "has_property_release"
            case id
            case imageType = "image_type"
            case isAdult = "is_adult"
            case isEditorial = "is_editorial"
            case isIllustration = "is_illustration"
            case keywords
            case mediaType = "media_type"
            case modelReleases = "model_releases"
            case models
            case releases
            case url
        }
    }

    // Image asset information
    struct ImageAsset: Codable
    {
        let hugeJpg: ImageSize?
        let hugeThumb: ImageThumbnail?
        let largeThumb: ImageThumbnail?
        let mediumJpg: ImageSize?
        let preview: ImageThumbnail?
        let preview1000: ImageThumbnail?
        let preview1500: ImageThumbnail?
        let smallJpg: ImageSize?
        let smallThumb: ImageThumbnail?
        let supersizeJpg: ImageSize?
        let vectorEps: ImageSize?
        let mosaic: ImageThumbnail?

        enum CodingKeys: String, CodingKey
        {
            case hugeJpg = "huge_jpg"
            case hugeThumb = "huge_thumb"
            case largeThumb = "large_thumb"
            case mediumJpg = "medium_jpg"
            case preview
            case preview1000 = "preview_1000"
            case preview1500 = "preview_1500"
            case smallJpg = "small_jpg"
            case smallThumb = "small_thumb"
            case supersizeJpg = "supersize_jpg"
            case vectorEps = "vector_eps"
            case mosaic
        }
    }

    // Image size information
    struct ImageSize: Codable
    {
        let displayName: String?
        let dpi: Int?
        let fileSize: Int?
        let format: String?
        let height: Int?
        let isLicensable: Bool?
        let width: Int?

        enum CodingKeys: String, CodingKey
        {
            case displayName = "display_name"
            case dpi
            case fileSize = "file_size"
            case format
            case height
            case isLicensable = "is_licensable"
            case width
        }
    }

    // Image thumbnail information
    struct ImageThumbnail: Codable
    {
        let height: Int
        let url: String
        let width: Int

        enum CodingKeys: String, CodingKey
        {
            case height
            case url
            case width
        }
    }


    // Category information
    struct Category: Codable
    {
        let id: String?
        let name: String?

        enum CodingKeys: String, CodingKey
        {
            case id
            case name
        }
    }

    // Information about a contributor
    struct Contributor: Codable
    {
        let id: String

        enum CodingKeys: String, CodingKey
        {
            case id
        }
    }

    // Model and property release metadata
    struct ModelPropertyRelease: Codable
    {
        let id: String?

        enum CodingKeys: String, CodingKey
        {
            case id
        }
    }

    // Information about a human model or property that appears in media; used to search for assets that this model is in
    struct HumanModelPropertyAppearsMedia: Codable
    {
        let id: String

        enum CodingKeys: String, CodingKey
        {
            case id
        }
    }


}
