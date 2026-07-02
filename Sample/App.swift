//
//  UUSwiftNetworkingSampleApp.swift
//  UUSwiftNetworkingSample
//
//  Created by Ryan DeVore on 6/1/26.
//

import SwiftUI
import UUSwiftCore

private let LOG_TAG = "App"

/*
class AppDelegate: NSObject, UIApplicationDelegate
{
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        UULog.debug(tag: LOG_TAG, message: "didFinishLaunchingWithOptions, launchOptions: \(String(describing: launchOptions))")
        //FirebaseApp.configure()
        //configureLogging()
        return true
    }
    
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool
    {
        UULog.debug(tag: LOG_TAG, message: "willContinueUserActivityWithType: \(userActivityType)")
        
        return true
        
    }
}*/

/*
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ContentView())
        window.makeKeyAndVisible()
        self.window = window

        // URL at launch (custom scheme)
        if let url = connectionOptions.urlContexts.first?.url {
            AuthCoordinator.shared.handle(url)
        }

        // Universal Link at launch
        if let userActivity = connectionOptions.userActivities.first,
           userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            AuthCoordinator.shared.handle(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        AuthCoordinator.shared.handle(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        AuthCoordinator.shared.handle(url)
    }
}
*/

@main
struct SampleApp: App
{
    //@UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    private let menuViewModel = MenuViewModel()
    private let accountViewModel = AccountViewModel()
    
    init()
    {
        let appConfig = AppConfig.shared
        
        let logger = UULogger.console
        logger.logLevel = .debug
        UULog.setLogger(logger)
        
        UULog.debug(tag: LOG_TAG, message: "AppConfig: \(appConfig)")
    }
    
    var body: some Scene
    {
        WindowGroup
        {
            RootView()
                .environmentObject(menuViewModel)
                .environmentObject(accountViewModel)
                .onOpenURL
                { url in
                    UULog.debug(tag: LOG_TAG, message: "On Open URL called: \(url)")
                    //accountViewModel.finishLogin(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb)
                { activity in
                    UULog.debug(tag: LOG_TAG, message: "On Open URL called: \(activity)")
                }
        }
    }
}
