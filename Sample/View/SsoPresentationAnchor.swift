//
//  SsoPresentationAnchor.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/25/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//

import Foundation
import AuthenticationServices

public class SsoPresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding
{
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor
    {
        // Just grab the first connected window
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first
        else
        {
            // Fallback to creating a new window
            return UIWindow()
        }
        
        return window
    }
}
