//
//  ShutterstockViewModel.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/9/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import Combine

class ShutterstockViewModel: ObservableObject
{
    @Published var showConfig: Bool = false
    
    @Published var clientKey: String = ""
    @Published var clientSecret: String = ""

}
