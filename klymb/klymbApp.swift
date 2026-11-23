//
//  klymbApp.swift
//  klymb
//
//  Main application entry point.
//

import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationManager.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }
}

@main
struct klymbApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState
    private let container: AppContainer

    init() {
        let container = AppContainer()
        let state = AppState(container: container)
        self.container = container
        self._appState = StateObject(wrappedValue: state)
        NotificationManager.shared.configure(service: container.notificationService, appState: state)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

