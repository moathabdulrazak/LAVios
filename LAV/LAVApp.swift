//
//  LAVApp.swift
//  LAV
//
//  Created by Mo on 2/11/26.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .all

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

@main
struct LAVApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authVM = AuthViewModel()
    @State private var gamesVM = GamesViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authVM)
                .environment(gamesVM)
                .preferredColorScheme(.dark)
        }
    }
}
