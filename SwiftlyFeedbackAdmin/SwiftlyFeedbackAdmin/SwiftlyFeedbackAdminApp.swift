//
//  SwiftlyFeedbackAdminApp.swift
//  SwiftlyFeedbackAdmin
//
//  Created by Ben Van Aken on 03/01/2026.
//

import SwiftUI
import SwiftlyFeedbackKit

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Synchronously logout when app is quitting
        logoutOnTermination()
    }

    private func logoutOnTermination() {
        // Check for token in a sync-safe way using KeychainManager directly
        // Read environment from Keychain directly (avoids MainActor isolation issues during termination)
        // Default to "development" for DEBUG builds, "production" for release builds
        #if DEBUG
        let defaultEnv = "development"
        #else
        let defaultEnv = "production"
        #endif
        let envKey: String
        if let envData = KeychainManager.get(forKey: "global.selectedEnvironment"),
           let storedEnv = String(data: envData, encoding: .utf8) {
            envKey = storedEnv
        } else {
            envKey = defaultEnv
        }
        guard KeychainManager.get(forKey: "\(envKey).authToken") != nil else { return }

        // Try to invalidate token on server (best effort, synchronous)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await AdminAPIClient.shared.post(path: "auth/logout", requiresAuth: true)
            } catch {
                // Ignore errors - we'll delete the token locally anyway
            }
            semaphore.signal()
        }
        // Wait briefly for the server call, but don't block termination too long
        _ = semaphore.wait(timeout: .now() + 1.0)

        // Delete local token after server call using KeychainManager directly
        KeychainManager.delete(forKey: "\(envKey).authToken")
    }
}
#endif

@main
struct SwiftlyFeedbackAdminApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    #endif

    @State private var deepLinkManager = DeepLinkManager.shared
    @State private var developerCenterViewModel = ProjectViewModel()

    init() {
        // Configure subscription service at app launch
        SubscriptionService.shared.configure()

        // Configure SwiftlyFeedbackKit SDK for in-app feature requests
        // Uses environment-specific API key from AppConfiguration
        AppConfiguration.shared.configureSDK()
    }

    var body: some Scene {
        // Main app window
        WindowGroup {
            RootView()
                .environment(SubscriptionService.shared)
                .environment(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handleURL(url)
                }
        }
        #if os(macOS)
        .commands {
            // Disable Cmd+N to prevent multiple main windows
            CommandGroup(replacing: .newItem) { }

            // Developer Center menu item
            CommandGroup(after: .appSettings) {
                Button("Developer Center...") {
                    openWindow(id: "developer-center")
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])
            }
        }
        #endif

        // Developer Center window (macOS only, single instance)
        #if os(macOS)
        Window("Developer Center", id: "developer-center") {
            DeveloperCenterView(projectViewModel: developerCenterViewModel, isStandaloneWindow: true)
                .environment(SubscriptionService.shared)
                .frame(minWidth: 500, minHeight: 600)
                .task {
                    await developerCenterViewModel.loadProjects()
                }
        }
        .defaultSize(width: 550, height: 650)
        #endif
    }
}
