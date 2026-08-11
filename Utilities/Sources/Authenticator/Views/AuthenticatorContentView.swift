import SwiftUI

struct AuthenticatorContentView: View {
    @Environment(AppState.self) private var appState

    @State private var userKey = ""
    @State private var keyConfirmation = ""
    @State private var errorMessage = ""
    @State private var isUnlocking = false

    var body: some View {
        Group {
            if let initializationError = appState.initializationError {
                ContentUnavailableView {
                    Label(
                        "身份验证器不可用",
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(initializationError)
                } actions: {
                    Button("重试") { appState.initialize() }
                }
            } else if appState.isUnlocked {
                TOTPListView()
            } else {
                unlockView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(isUnlocking)
        .overlay {
            if isUnlocking {
                ZStack {
                    Rectangle().fill(.black.opacity(0.22)).ignoresSafeArea()
                    ProgressView(appState.isConfigured ? "正在解锁…" : "正在创建加密存储…")
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .allowsHitTesting(true)
            }
        }
    }

    private var unlockView: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield")
                .font(.system(size: 46))
                .foregroundStyle(.cyan)

            VStack(spacing: 6) {
                Text(appState.isConfigured ? "解锁身份验证器" : "设置身份验证器密钥")
                    .font(.title2.bold())
                Text(
                    appState.isConfigured
                        ? "密钥仅保留在内存中，关闭功能后需要重新输入。"
                        : "数据将使用 AES-256-GCM 加密。密钥遗失后无法恢复。"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                SecureField("输入密钥", text: $userKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(beginUnlock)

                if !appState.isConfigured {
                    SecureField("再次输入密钥", text: $keyConfirmation)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(beginUnlock)
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(appState.isConfigured ? "解锁" : "创建并启动", action: beginUnlock)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(
                    userKey.isEmpty
                        || (!appState.isConfigured && keyConfirmation.isEmpty)
                )
        }
        .frame(maxWidth: 320)
        .padding(36)
    }

    private func beginUnlock() {
        if !appState.isConfigured && userKey != keyConfirmation {
            errorMessage = "两次输入的密钥不一致"
            return
        }

        let submittedKey = userKey
        isUnlocking = true
        Task {
            defer { isUnlocking = false }
            do {
                try await appState.unlock(with: submittedKey)
                userKey = ""
                keyConfirmation = ""
                errorMessage = ""
            } catch {
                userKey = ""
                keyConfirmation = ""
                errorMessage = error.localizedDescription
            }
        }
    }
}
