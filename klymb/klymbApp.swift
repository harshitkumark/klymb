//
//  klymbApp.swift
//  klymb
//
//  Main application entry point.
//

import SwiftUI

@main
struct klymbApp: App {
    @StateObject private var appState: AppState
    private let container: AppContainer

    init() {
        let container = AppContainer()
        self.container = container
        self._appState = StateObject(wrappedValue: AppState(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
