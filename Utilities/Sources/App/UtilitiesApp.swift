import AppKit
import SwiftUI

@main
@MainActor
struct UtilitiesApp: App {
    var body: some Scene {
        WindowGroup(
            AppConstants.Application.displayName,
            id: AppConstants.Application.launcherWindowID
        ) {
            LauncherView()
                .frame(
                    minWidth: AppConstants.Application.launcherMinimumWidth,
                    minHeight: AppConstants.Application.launcherMinimumHeight
                )
        }
        .windowResizability(.contentMinSize)

        Window(
            AppConstants.Application.subTrackName,
            id: AppConstants.Application.subTrackWindowID
        ) {
            SubTrackRootView()
                .frame(
                    minWidth: AppConstants.Application.subTrackMinimumWidth,
                    minHeight: AppConstants.Application.subTrackMinimumHeight
                )
        }
        .windowStyle(.titleBar)

        Window(
            AppConstants.Application.authenticatorName,
            id: AppConstants.Application.authenticatorWindowID
        ) {
            AuthenticatorRootView()
                .frame(
                    minWidth: AppConstants.Application.authenticatorMinimumWidth,
                    minHeight: AppConstants.Application.authenticatorMinimumHeight
                )
        }
        .windowStyle(.titleBar)
    }
}

private struct SubTrackRootView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var model: AppModel?

    var body: some View {
        Group {
            if let model {
                SubTrackContentView()
                    .environment(model)
            } else {
                ProgressView(AppConstants.Application.loadingSubTrack)
                    .onAppear {
                        guard model == nil else { return }
                        model = AppModel()
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
            ($0.object as! NSWindow).preventsApplicationTerminationWhenModal = false
        }
        .onDisappear {
            openWindow(id: AppConstants.Application.launcherWindowID)
        }
    }
}

private struct AuthenticatorRootView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var appState = AppState()

    var body: some View {
        AuthenticatorContentView()
            .environment(appState)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
                ($0.object as! NSWindow).preventsApplicationTerminationWhenModal = false
            }
            .onDisappear {
                appState.lock()
                openWindow(id: AppConstants.Application.launcherWindowID)
            }
    }
}
