import AppKit
import SwiftUI

private struct SubTrackCommandContext {
    let canCreateProject: Bool
    let createProject: () -> Void
}

private struct SubTrackCommandContextKey: FocusedValueKey {
    typealias Value = SubTrackCommandContext
}

private extension FocusedValues {
    var subTrackCommandContext: SubTrackCommandContext? {
        get { self[SubTrackCommandContextKey.self] }
        set { self[SubTrackCommandContextKey.self] = newValue }
    }
}

private struct SubTrackCommands: Commands {
    @FocusedValue(\.subTrackCommandContext) private var context

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(AppConstants.Application.newProject) {
                context?.createProject()
            }
            .keyboardShortcut(AppConstants.Application.newProjectShortcut)
            .disabled(context?.canCreateProject != true)
        }
    }
}

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
        .commands {
            SubTrackCommands()
        }

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
                    .focusedSceneValue(
                        \.subTrackCommandContext,
                        SubTrackCommandContext(
                            canCreateProject: model.canCreateProject,
                            createProject: { model.presentedSheet = .editor(nil) }
                        )
                    )
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
