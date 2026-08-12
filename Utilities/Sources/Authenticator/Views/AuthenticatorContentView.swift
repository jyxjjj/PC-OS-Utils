import SwiftUI

struct AuthenticatorContentView: View {
    @Environment(AppState.self) private var appState

    @State private var userKey = ""
    @State private var keyConfirmation = ""
    @State private var confirmationError = ""
    @State private var errorMessage = ""
    @State private var isUnlocking = false

    var body: some View {
        Group {
            if let initializationError = appState.initializationError {
                ContentUnavailableView {
                    Label(
                        AppConstants.Authenticator.Unlock.unavailable,
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(initializationError)
                } actions: {
                    Button(AppConstants.Authenticator.Unlock.retry) { appState.initialize() }
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
                    Rectangle()
                        .fill(.black.opacity(AppConstants.Authenticator.Unlock.overlayOpacity))
                        .ignoresSafeArea()
                    ProgressView(
                        appState.isConfigured
                            ? AppConstants.Authenticator.Unlock.unlocking
                            : AppConstants.Authenticator.Unlock.creatingStore
                    )
                        .controlSize(.large)
                        .padding(AppConstants.Authenticator.Unlock.progressPadding)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(
                                cornerRadius: AppConstants.Authenticator.Unlock.progressCornerRadius
                            )
                        )
                }
                .allowsHitTesting(true)
            }
        }
    }

    private var unlockView: some View {
        VStack(spacing: AppConstants.Authenticator.Unlock.contentSpacing) {
            Image(systemName: "lock.shield")
                .font(.system(size: AppConstants.Authenticator.Unlock.lockSymbolSize))
                .foregroundStyle(.cyan)

            VStack(spacing: AppConstants.Authenticator.Unlock.titleSpacing) {
                Text(
                    appState.isConfigured
                        ? AppConstants.Authenticator.Unlock.unlockTitle
                        : AppConstants.Authenticator.Unlock.setupTitle
                )
                    .font(.title2.bold())
                Text(
                    appState.isConfigured
                        ? AppConstants.Authenticator.Unlock.configuredDescription
                        : AppConstants.Authenticator.Unlock.setupDescription
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(spacing: AppConstants.Authenticator.Unlock.fieldsSpacing) {
                VStack(alignment: .leading) {
                    Text(AppConstants.Authenticator.Unlock.keyPrompt)
                    SecureField("", text: $userKey)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(beginUnlock)
                }

                if !appState.isConfigured {
                    VStack(alignment: .leading) {
                        Text(AppConstants.Authenticator.Unlock.confirmationPrompt)
                        SecureField("", text: $keyConfirmation)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(beginUnlock)
                        if !confirmationError.isEmpty {
                            Text(confirmationError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(
                appState.isConfigured
                    ? AppConstants.Authenticator.Unlock.unlock
                    : AppConstants.Authenticator.Unlock.createAndLaunch,
                action: beginUnlock
            )
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(
                    userKey.isEmpty
                        || (!appState.isConfigured && keyConfirmation.isEmpty)
                )
        }
        .frame(maxWidth: AppConstants.Authenticator.Unlock.maximumContentWidth)
        .padding(AppConstants.Authenticator.Unlock.contentPadding)
        .onChange(of: keyConfirmation) { _, _ in confirmationError = "" }
    }

    private func beginUnlock() {
        confirmationError = ""
        errorMessage = ""
        if !appState.isConfigured && userKey != keyConfirmation {
            confirmationError = AppConstants.Authenticator.Unlock.mismatchedKeys
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
                confirmationError = ""
                errorMessage = ""
            } catch {
                userKey = ""
                keyConfirmation = ""
                confirmationError = ""
                errorMessage = error.localizedDescription
            }
        }
    }
}
