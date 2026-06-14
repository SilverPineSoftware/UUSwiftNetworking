//
//  ShutterstockApi.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/3/26.
//

import Foundation
import UUSwiftCore
import UUSwiftNetworking

nonisolated private let LOG_TAG = "ShutterstockApi"

nonisolated class ShutterstockApi: UURemoteApi
{
    private static let maxPerPage = 500
    private let baseUrl = "https://api.shutterstock.com"
    
    public override init()
    {
        super.init()
    }
    
    func formatUrl(_ endpoint: ShutterstockEndpoint) -> String
    {
        return "\(baseUrl)\(endpoint.rawValue)"
    }
    
    func searchImages(query: String, count: Int, large: Bool) async -> Result<[String], Error>
    {
        var results: [String] = []
        
        let pages = (count / Self.maxPerPage) + 1
        let perPage = min(Self.maxPerPage, count)
        
        for page in 1..<(pages+1)
        {
            let pageResult = await searchImagePage(query: query, page: page, count: perPage, large: large)
            
            switch (pageResult)
            {
                case .success(let pageResults):
                    results.append(contentsOf: pageResults)
                case .failure(let error):
                    return .failure(error)
            }
        }
        
        return .success(results)
    }
    
    func searchImagePage(query: String, page: Int, count: Int, large: Bool) async -> Result<[String], Error>
    {
        //https://api.shutterstock.com/v2/images/search
        let req = UUCodableHttpRequest<ShutterstockSearchImagesResponse, ShutterstockError>(url: formatUrl(ShutterstockEndpoint.searchImages))
        
        var args: UUQueryStringArgs = [:]
        args["page"] = "\(page)"
        args["per_page"] = "\(count)" // 500 is the max allowed
        args["query"] = query
        
        req.queryArguments = args
        
        let result = await executeCodableRequest(req)
        
        switch (result)
        {
            case .success(let searchResult):
                UULog.debug(tag: LOG_TAG, message: "Success!")
            
                let allAssets = searchResult.data.compactMap(\.assets)
                
                if (large)
                {
                    let largeAssets = allAssets.compactMap(\.preview1500)
                    return .success(largeAssets.compactMap(\.url))
                }
                else
                {
                    let smallAssets = allAssets.compactMap(\.smallThumb)
                    return .success(smallAssets.compactMap(\.url))
                }
            
            case .failure(let error):
                // TODO: Translate into api specific error
                UULog.debug(tag: LOG_TAG, message: "Api returned an error: \(error)")
                return .failure(error)
        }
    }
}

enum ShutterstockEndpoint: String
{
    case searchImages = "/v2/images/search"    
}

// Error object
struct ShutterstockError: Codable
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
struct ShutterstockSearchImagesResponse: Codable
{
    let data: [ShutterstockGetImageResponse]
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
struct ShutterstockGetImageResponse: Codable
{
    let addedDate: String?
    let affiliateUrl: String?
    let aspect: Float?
    let assets: ShutterstockImageAsset?
    let categories: [ShutterstockCategory]?
    let contributor: ShutterstockContributor
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
    let modelReleases: [ShutterstockModelPropertyRelease]?
    let models: [ShutterstockHumanModelPropertyAppearsMedia]?
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
struct ShutterstockImageAsset: Codable
{
    let hugeJpg: ShutterstockImageSize?
    let hugeThumb: ShutterstockImageThumbnail?
    let largeThumb: ShutterstockImageThumbnail?
    let mediumJpg: ShutterstockImageSize?
    let preview: ShutterstockImageThumbnail?
    let preview1000: ShutterstockImageThumbnail?
    let preview1500: ShutterstockImageThumbnail?
    let smallJpg: ShutterstockImageSize?
    let smallThumb: ShutterstockImageThumbnail?
    let supersizeJpg: ShutterstockImageSize?
    let vectorEps: ShutterstockImageSize?
    let mosaic: ShutterstockImageThumbnail?

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
struct ShutterstockImageSize: Codable
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
struct ShutterstockImageThumbnail: Codable
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
struct ShutterstockCategory: Codable
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
struct ShutterstockContributor: Codable
{
    let id: String

    enum CodingKeys: String, CodingKey
    {
        case id
    }
}

// Model and property release metadata
struct ShutterstockModelPropertyRelease: Codable
{
    let id: String?

    enum CodingKeys: String, CodingKey
    {
        case id
    }
}

// Information about a human model or property that appears in media; used to search for assets that this model is in
struct ShutterstockHumanModelPropertyAppearsMedia: Codable
{
    let id: String

    enum CodingKeys: String, CodingKey
    {
        case id
    }
}

/*
// https://api-reference.shutterstock.com/#schema-error
struct ShutterstockError: Codable
{
    let message: String
    let code: String?
    let data: String?
    let items: [String]?
    let path: String?
    let statusCode: Int?
}

// https://api-reference.shutterstock.com/#schema-image-search-results
struct ShutterstockSearchImagesResponse: Codable
{
    let data: [ShutterstockImage]
    let searchId: String
    let totalCount: Int
    let errors: [ShutterstockError]?
    let message: String?
    let page: Int?
    let perPage: Int?
    let spellcheckInfo: ShutterstockSpellcheckInfo?
}

struct ShutterstockSpellcheckInfo: Codable
{
    let spellcheckedQuery: String?
    let origQuery: String?
    let origResultsCount: Int?
}

// https://api-reference.shutterstock.com/#schema-image
struct ShutterstockImage: Codable
{
    let id: String
    let aspect: Float
    let assets: ShutterstockImageAssets
    let contributor: ShutterstockContributor
    let description: String
    let imageType: String
    let hasModelRelease: Bool
    let mediaType: String
    let url: String
}

// https://api-reference.shutterstock.com/#schema-image-assets
struct ShutterstockImageAssets: Codable
{
    let hugeJpg: ShutterstockImageSizeDetails?
    let hugeThumb: ShutterstockThumbnail?
    let largeThumb: ShutterstockThumbnail?
    let mediumJpg: ShutterstockImageSizeDetails?
    let mosaicThumb: ShutterstockThumbnail?
    let previewThumb: ShutterstockThumbnail?
    let preview1000: ShutterstockThumbnail?
    let preview1500: ShutterstockThumbnail?
    let smallJpg: ShutterstockImageSizeDetails?
    let smallThumb: ShutterstockThumbnail?
    let supersizeJpg: ShutterstockImageSizeDetails?
    let vectorEps: ShutterstockImageSizeDetails?
}

// https://api-reference.shutterstock.com/#schema-image-size-details
struct ShutterstockImageSizeDetails: Codable
{
    let displayName: String?
    let dpi: Int?
    let fileSize: Int?
    let format: String?
    let height: Int?
    let isLicensable: Bool?
    let width: Int?
}

// https://api-reference.shutterstock.com/#schema-thumbnail
struct ShutterstockThumbnail: Codable
{
    let width: Int
    let height: Int
    let url: String
}

// https://api-reference.shutterstock.com/#schema-contributor
struct ShutterstockContributor: Codable
{
    let id: String
    let name: String?
}*/
 

/*
{
  "total_count": 30745214,
  "search_id": "d34caf54-1a04-4e67-8954-dcfd1366f4d4",
  "page": 1,
  "per_page": 5,
  "spellcheck_info": {
    "spellchecked_query": null,
    "orig_query": "forest",
    "orig_results_count": 0
  },
  "data": [
    {
      "id": "2730669441",
      "aspect": 1.75,
      "assets": {
        "preview": {
          "height": 258,
          "width": 450,
          "url": "https://image.shutterstock.com/image-photo/majestic-woods-dramatic-sunbeams-illuminating-450w-2730669441.jpg"
        },
        "small_thumb": {
          "height": 58,
          "width": 100,
          "url": "https://image.shutterstock.com/image-photo/majestic-woods-dramatic-sunbeams-illuminating-100nw-2730669441.jpg"
        },
        "large_thumb": {
          "height": 86,
          "width": 150,
          "url": "https://image.shutterstock.com/image-photo/majestic-woods-dramatic-sunbeams-illuminating-150nw-2730669441.jpg"
        },
        "mosaic": {
          "height": 143,
          "width": 250,
          "url": "https://image.shutterstock.com/image-photo/majestic-woods-dramatic-sunbeams-illuminating-250nw-2730669441.jpg"
        },
        "preview_600": {
          "height": 343,
          "width": 600,
          "url": "https://image.shutterstock.com/image-photo/majestic-woods-dramatic-sunbeams-illuminating-600w-2730669441.jpg"
        },
        "preview_1000": {
          "height": 572,
          "width": 1000,
          "url": "https://image.shutterstock.com/image-photo/majestic-woods-dramatic-sunbeams-illuminating-1000w-2730669441.jpg"
        },
        "preview_1500": {
          "height": 858,
          "width": 1500,
          "url": "https://image.shutterstock.com/z/stock-photo-majestic-woods-dramatic-sunbeams-illuminating-a-green-mossy-forest-floor-2730669441.jpg"
        },
        "huge_thumb": {
          "height": 260,
          "width": 455,
          "url": "https://image.shutterstock.com/image-photo/majestic-woods-dramatic-sunbeams-illuminating-260nw-2730669441.jpg"
        }
      },
      "contributor": {
        "id": "466368535"
      },
      "description": "Majestic Woods: Dramatic Sunbeams Illuminating a Green Mossy Forest Floor.",
      "image_type": "photo",
      "has_model_release": false,
      "media_type": "image",
      "url": "https://www.shutterstock.com/image-photo/majestic-woods-dramatic-sunbeams-illuminating-green-2730669441"
    },
    {
      "id": "2699479365",
      "aspect": 1.8332,
      "assets": {
        "preview": {
          "height": 246,
          "width": 450,
          "url": "https://image.shutterstock.com/image-vector/collection-various-stylized-green-trees-450w-2699479365.jpg"
        },
        "small_thumb": {
          "height": 55,
          "width": 100,
          "url": "https://image.shutterstock.com/image-vector/collection-various-stylized-green-trees-100nw-2699479365.jpg"
        },
        "large_thumb": {
          "height": 82,
          "width": 150,
          "url": "https://image.shutterstock.com/image-vector/collection-various-stylized-green-trees-150nw-2699479365.jpg"
        },
        "mosaic": {
          "height": 137,
          "width": 250,
          "url": "https://image.shutterstock.com/image-vector/collection-various-stylized-green-trees-250nw-2699479365.jpg"
        },
        "preview_600": {
          "height": 328,
          "width": 600,
          "url": "https://image.shutterstock.com/image-vector/collection-various-stylized-green-trees-600w-2699479365.jpg"
        },
        "preview_1000": {
          "height": 546,
          "width": 1000,
          "url": "https://image.shutterstock.com/image-vector/collection-various-stylized-green-trees-1000w-2699479365.jpg"
        },
        "preview_1500": {
          "height": 819,
          "width": 1500,
          "url": "https://image.shutterstock.com/z/stock-vector-a-collection-of-various-stylized-green-trees-and-bushes-in-a-flat-design-aesthetic-2699479365.jpg"
        },
        "huge_thumb": {
          "height": 260,
          "width": 476,
          "url": "https://image.shutterstock.com/image-vector/collection-various-stylized-green-trees-260nw-2699479365.jpg"
        }
      },
      "contributor": {
        "id": "474387635"
      },
      "description": "A collection of various stylized green trees and bushes in a flat design aesthetic.",
      "image_type": "vector",
      "has_model_release": false,
      "media_type": "image",
      "url": "https://www.shutterstock.com/image-photo/collection-various-stylized-green-trees-bushes-2699479365"
    },
    {
      "id": "2593337003",
      "aspect": 1.5,
      "assets": {
        "preview": {
          "height": 300,
          "width": 450,
          "url": "https://image.shutterstock.com/image-photo/mountain-trail-scene-landscape-hiking-450w-2593337003.jpg"
        },
        "small_thumb": {
          "height": 67,
          "width": 100,
          "url": "https://image.shutterstock.com/image-photo/mountain-trail-scene-landscape-hiking-100nw-2593337003.jpg"
        },
        "large_thumb": {
          "height": 100,
          "width": 150,
          "url": "https://image.shutterstock.com/image-photo/mountain-trail-scene-landscape-hiking-150nw-2593337003.jpg"
        },
        "mosaic": {
          "height": 167,
          "width": 250,
          "url": "https://image.shutterstock.com/image-photo/mountain-trail-scene-landscape-hiking-250nw-2593337003.jpg"
        },
        "preview_600": {
          "height": 400,
          "width": 600,
          "url": "https://image.shutterstock.com/image-photo/mountain-trail-scene-landscape-hiking-600w-2593337003.jpg"
        },
        "preview_1000": {
          "height": 667,
          "width": 1000,
          "url": "https://image.shutterstock.com/image-photo/mountain-trail-scene-landscape-hiking-1000w-2593337003.jpg"
        },
        "preview_1500": {
          "height": 1000,
          "width": 1500,
          "url": "https://image.shutterstock.com/z/stock-photo-mountain-trail-scene-mountain-landscape-with-hiking-trail-mountain-trail-in-the-alps-pathway-2593337003.jpg"
        },
        "huge_thumb": {
          "height": 260,
          "width": 390,
          "url": "https://image.shutterstock.com/image-photo/mountain-trail-scene-landscape-hiking-260nw-2593337003.jpg"
        }
      },
      "contributor": {
        "id": "303289"
      },
      "description": "Mountain trail scene. Mountain landscape with hiking trail. Mountain trail in the Alps. Pathway walking path in picturesque mountain landscape. Hiking trail through forest meadow. Travel destination",
      "image_type": "photo",
      "has_model_release": false,
      "media_type": "image",
      "url": "https://www.shutterstock.com/image-photo/mountain-trail-scene-landscape-hiking-alps-2593337003"
    },
    {
      "id": "2716444763",
      "aspect": 0.75,
      "assets": {
        "preview": {
          "height": 450,
          "width": 337,
          "url": "https://image.shutterstock.com/image-photo/experience-tranquility-kayaking-crystal-blue-450w-2716444763.jpg"
        },
        "small_thumb": {
          "height": 100,
          "width": 75,
          "url": "https://image.shutterstock.com/image-photo/experience-tranquility-kayaking-crystal-blue-100nw-2716444763.jpg"
        },
        "large_thumb": {
          "height": 150,
          "width": 112,
          "url": "https://image.shutterstock.com/image-photo/experience-tranquility-kayaking-crystal-blue-150nw-2716444763.jpg"
        },
        "mosaic": {
          "height": 250,
          "width": 187,
          "url": "https://image.shutterstock.com/image-photo/experience-tranquility-kayaking-crystal-blue-250nw-2716444763.jpg"
        },
        "preview_600": {
          "height": 600,
          "width": 450,
          "url": "https://image.shutterstock.com/image-photo/experience-tranquility-kayaking-crystal-blue-600w-2716444763.jpg"
        },
        "preview_1000": {
          "height": 1000,
          "width": 750,
          "url": "https://image.shutterstock.com/image-photo/experience-tranquility-kayaking-crystal-blue-1000w-2716444763.jpg"
        },
        "preview_1500": {
          "height": 1500,
          "width": 1125,
          "url": "https://image.shutterstock.com/z/stock-photo-experience-the-tranquility-of-kayaking-in-crystal-blue-waters-surrounded-by-vibrant-green-mangrove-2716444763.jpg"
        },
        "huge_thumb": {
          "height": 260,
          "width": 195,
          "url": "https://image.shutterstock.com/image-photo/experience-tranquility-kayaking-crystal-blue-260nw-2716444763.jpg"
        }
      },
      "contributor": {
        "id": "1800977"
      },
      "description": "Experience the tranquility of kayaking in crystal blue waters surrounded by vibrant green mangrove forests on Koh Phayam Island, Thailand. A perfect escape into natures beauty awaits.",
      "image_type": "photo",
      "has_model_release": false,
      "media_type": "image",
      "url": "https://www.shutterstock.com/image-photo/experience-tranquility-kayaking-crystal-blue-waters-2716444763"
    },
    {
      "id": "2695557961",
      "aspect": 1.5,
      "assets": {
        "preview": {
          "height": 300,
          "width": 450,
          "url": "https://image.shutterstock.com/image-photo/matterhorn-swiss-alps-switzerland-landscape-450w-2695557961.jpg"
        },
        "small_thumb": {
          "height": 67,
          "width": 100,
          "url": "https://image.shutterstock.com/image-photo/matterhorn-swiss-alps-switzerland-landscape-100nw-2695557961.jpg"
        },
        "large_thumb": {
          "height": 100,
          "width": 150,
          "url": "https://image.shutterstock.com/image-photo/matterhorn-swiss-alps-switzerland-landscape-150nw-2695557961.jpg"
        },
        "mosaic": {
          "height": 167,
          "width": 250,
          "url": "https://image.shutterstock.com/image-photo/matterhorn-swiss-alps-switzerland-landscape-250nw-2695557961.jpg"
        },
        "preview_600": {
          "height": 400,
          "width": 600,
          "url": "https://image.shutterstock.com/image-photo/matterhorn-swiss-alps-switzerland-landscape-600w-2695557961.jpg"
        },
        "preview_1000": {
          "height": 667,
          "width": 1000,
          "url": "https://image.shutterstock.com/image-photo/matterhorn-swiss-alps-switzerland-landscape-1000w-2695557961.jpg"
        },
        "preview_1500": {
          "height": 1000,
          "width": 1500,
          "url": "https://image.shutterstock.com/z/stock-photo-matterhorn-swiss-alps-switzerland-landscape-image-of-swiss-alps-with-iconic-peak-matterhorn-in-2695557961.jpg"
        },
        "huge_thumb": {
          "height": 260,
          "width": 390,
          "url": "https://image.shutterstock.com/image-photo/matterhorn-swiss-alps-switzerland-landscape-260nw-2695557961.jpg"
        }
      },
      "contributor": {
        "id": "576352"
      },
      "description": "Matterhorn, Swiss Alps, Switzerland. Landscape image of Swiss Alps with iconic peak Matterhorn in the background at beautiful autumn sunset.",
      "image_type": "photo",
      "has_model_release": false,
      "media_type": "image",
      "url": "https://www.shutterstock.com/image-photo/matterhorn-swiss-alps-switzerland-landscape-image-2695557961"
    }
  ]
}
*/


/*
class UUShutterstockApi
{
    private static let maxPerPage = 500
    
    class func fetchImageUrls(count: Int, large: Bool, callback: @escaping (([String])->()))
    {
        fetchAssets(workingResults: [], page: 1, count: count, query: "forest", assetKey: large ? "preview_1500" : "small_thumb", callback: callback)
    }
    
    private class func fetchAssets(workingResults: [String], page: Int, count: Int, query: String, assetKey: String, callback: @escaping (([String])->()))
    {
        if (workingResults.count >= count)
        {
            callback(workingResults)
            return
        }
        
        fetchAssetPage(page: page, perPage: min(count, maxPerPage), query: query, assetKey: assetKey)
        { pageResult in
            
            var tmp = workingResults
            tmp.append(contentsOf: pageResult)
            fetchAssets(workingResults: tmp, page: page + 1, count: count, query: query, assetKey: assetKey, callback: callback)
        }
    }
    
    private class func fetchAssetPage(page: Int, perPage: Int, query: String, assetKey: String, callback: @escaping (([String])->()))
    {
        let url = "https://api.shutterstock.com/v2/images/search"
        
        var args: UUQueryStringArgs = [:]
        args["page"] = "\(page)"
        args["per_page"] = "\(perPage)" // 500 is the max allowed
        args["query"] = query
        
        nonisolated(unsafe) let req = UUHttpRequest(url: url, method: .get, queryArguments: args)
        
        let username = "d4a89-1400b-04251-4faee-f7a23-12271:61764-d9c3c-8a832-a7bdf-098e4-0b382"
        let usernameData = username.data(using: .utf8)
        let usernameEncoded = usernameData!.base64EncodedString(options: Data.Base64EncodingOptions.init(rawValue: 0))
        req.headerFields["Authorization"] = "Basic \(usernameEncoded)"
        
        nonisolated(unsafe) let done = callback
            
        UUTestLog("Fetching page \(page)")
        Task
        {
            let response = await UUHttpSession.executeRequest(req)
            
            var results: [String] = []
            
            if (response.httpError == nil)
            {
                if let parsed = response.parsedResponse as? [AnyHashable:Any],
                   let data = parsed.uuGetDictionaryArray("data")
                {
                    for item in data
                    {
                        //UUTestLog("item: \(item)")
                        
                        if let assets = item.uuGetDictionary("assets")
                        {
                            //small_thumb
                            //large_thumb
                            //huge_thumb
                            //preview
                            //preview_1000
                            //preview_1500
                            
                            //UUTestLog("item: \(item)")
                            
                            if let d = assets.uuGetDictionary(assetKey),
                               let url = d.uuGetString("url")
                            {
                                if (!results.contains(url))
                                {
                                    //UUTestLog("Adding URL: \(url)")
                                    results.append(url)
                                }
                            }
                        }
                    }
                }
            }
            
            done(results)
        }
    }
}





fileprivate final class InsecureSessionDelegate: NSObject, URLSessionDelegate
{
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        // Only handle serverTrust challenges; fall back otherwise
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else
        {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Always trust
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}

fileprivate func createSessionConfiguration() -> URLSessionConfiguration
{
    let cfg = URLSessionConfiguration.ephemeral
    cfg.timeoutIntervalForRequest = UUHttpConfig.shared.defaultTimeout
    cfg.timeoutIntervalForResource = UUHttpConfig.shared.defaultTimeout
    cfg.httpAdditionalHeaders = [
        UUHeader.contentType: UUContentType.applicationJson
    ]
    
    cfg.waitsForConnectivity = false
    return cfg
}*/



//class FooApi: UURemoteApi
//{
//    required init()
//    {
//        let sessionConfig = createSessionConfiguration()
//        let sessionDelegate = InsecureSessionDelegate()
//        super.init(session: UUHttpSession(configuration: sessionConfig, delegate: sessionDelegate))
//    }
//}

/*
package com.silverpine.uu.sample.networking.shutterstock

import androidx.annotation.Keep
import com.silverpine.uu.core.UUError
import com.silverpine.uu.core.UUResult
import com.silverpine.uu.core.UUResultBlock
import com.silverpine.uu.networking.UUHttpLoggingMode
import com.silverpine.uu.networking.UUHttpMethod
import com.silverpine.uu.networking.UURemoteApi
import com.silverpine.uu.networking.UUTypedHttpRequest
import com.silverpine.uu.networking.authorization.UUBasicAuthorizationProvider
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class ShutterstockApi : UURemoteApi()
{
    private val baseUrl = "https://api.shutterstock.com/v2"

    var username: String = ""
        set(value)
        {
            field = value
            updateAuthProvider()
        }

    var password: String = ""
        set(value)
        {
            field = value
            updateAuthProvider()
        }

    private fun updateAuthProvider()
    {
        if (username.isNotBlank() && password.isNotBlank())
        {
            defaultAuthorizationProvider = UUBasicAuthorizationProvider(username, password)
        }
    }

    /**
     * Search Shutterstock images by keyword.
     */
    fun searchImages(
        query: String,
        page: Int = 1,
        perPage: Int = 20,
        completion: UUResultBlock<ShutterstockSearchResponse>
    ) {
        val request = UUTypedHttpRequest(
            url = "$baseUrl/images/search",
            query =
                hashMapOf("query" to query,
                    "page" to page.toString(),
                    "per_page" to perPage.toString(),
                    "image_type" to "photo"),
            successClass = ShutterstockSearchResponse::class.java,
            errorClass = ShutterstockErrorResponse::class.java
        ).apply {
            method = UUHttpMethod.GET
            loggingMode = UUHttpLoggingMode.Verbose
        }

        executeAuthorizedRequest(request) { response ->
            val parsed = response.parsedResponse as? ShutterstockSearchResponse
            if (parsed != null) {
                completion(UUResult.success(parsed))
            } else {
                completion(
                    UUResult.failure(
                        response.error ?: UUError(
                            code = -1,
                            domain = "ShutterstockApi"
                        )
                    )
                )
            }
        }
    }

}

@Keep
@Serializable
data class ShutterstockSearchResponse(
    val data: List<ShutterstockImage> = emptyList(),
    val page: Int = 0,

    @SerialName("per_page")
    val perPage: Int = 0,

    @SerialName("total_count")
    val totalCount: Int = 0
)

@Keep
@Serializable
data class ShutterstockImage(
    val id: String,
    val description: String? = null,
    val assets: ShutterstockAssets? = null
)

@Keep
@Serializable
data class ShutterstockAssets(
    val preview: ShutterstockAsset? = null,

    @SerialName("preview_1000")
    val preview1000: ShutterstockAsset? = null
)

@Keep
@Serializable
data class ShutterstockAsset(
    val url: String,
    val width: Int,
    val height: Int
)

@Keep
@Serializable
data class ShutterstockErrorResponse(
    val message: String? = null,
    val code: String? = null
)*/
