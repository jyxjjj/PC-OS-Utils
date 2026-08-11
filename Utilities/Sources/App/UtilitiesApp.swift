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
            Button("新建项目") {
                context?.createProject()
            }
            .keyboardShortcut("n")
            .disabled(context?.canCreateProject != true)
        }
    }
}

@main
@MainActor
struct UtilitiesApp: App {
    var body: some Scene {
        WindowGroup("DESMG Utilities", id: "launcher") {
            LauncherView()
                .frame(minWidth: 680, minHeight: 430)
        }
        .windowResizability(.contentMinSize)

        Window("SubTrack", id: "subtrack") {
            SubTrackRootView()
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .commands {
            SubTrackCommands()
        }

        Window("身份验证器", id: "authenticator") {
            AuthenticatorRootView()
                .frame(minWidth: 400, minHeight: 500)
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
                ProgressView("正在载入 SubTrack…")
                    .onAppear {
                        guard model == nil else { return }
                        model = AppModel()
                    }
            }
        }
        .onDisappear {
            openWindow(id: "launcher")
        }
    }
}

private struct AuthenticatorRootView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var appState = AppState()

    var body: some View {
        AuthenticatorContentView()
            .environment(appState)
            .onDisappear {
                appState.lock()
                openWindow(id: "launcher")
            }
    }
}
