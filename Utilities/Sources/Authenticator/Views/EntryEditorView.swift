import AppKit
import SwiftUI
import CryptoKit

private struct AuthenticatorRequiredFieldLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: AppConstants.Authenticator.Editor.requiredFieldSpacing) {
            Text(title)
            Text(AppConstants.Common.requiredFieldMarker).foregroundStyle(.red)
        }
        .font(.body)
    }
}

private struct AuthenticatorFieldError: View {
    let message: String

    var body: some View {
        if !message.isEmpty {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

private struct EntryFieldErrors {
    var serviceName = ""
    var username = ""
    var secret = ""
    var uri = ""
}

struct EntryEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let entry: TOTPEntry?

    @State private var serviceName: String
    @State private var username: String
    @State private var secret = ""
    @State private var algorithm: TOTPAlgorithm
    @State private var digits: Int
    @State private var period: Int
    @State private var uriString = ""
    @State private var showURIInput = false
    @State private var parsedURI: OTPAuthParameters?
    @State private var fieldErrors = EntryFieldErrors()
    @State private var globalError = ""
    @State private var isSaving = false

    init(entry: TOTPEntry? = nil) {
        self.entry = entry
        _serviceName = State(initialValue: entry?.serviceName ?? "")
        _username = State(initialValue: entry?.username ?? "")
        _algorithm = State(initialValue: entry?.algorithm ?? .sha256)
        _digits = State(initialValue: entry?.digits ?? AppConstants.Authenticator.defaultDigits)
        _period = State(initialValue: entry?.period ?? AppConstants.Authenticator.defaultPeriod)
    }

    var body: some View {
        VStack(spacing: AppConstants.Authenticator.Editor.contentSpacing) {
            HStack {
                Text(
                    entry == nil
                        ? AppConstants.Authenticator.Editor.addTitle
                        : AppConstants.Authenticator.Editor.editTitle
                )
                .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            Form {
                Section(AppConstants.Authenticator.Editor.accountSection) {
                    VStack(alignment: .leading) {
                        TextField(
                            text: $serviceName,
                            prompt: Text(AppConstants.Authenticator.Editor.servicePrompt)
                        ) {
                            AuthenticatorRequiredFieldLabel(
                                title: AppConstants.Authenticator.Editor.serviceName
                            )
                        }
                        AuthenticatorFieldError(message: fieldErrors.serviceName)
                    }
                    VStack(alignment: .leading) {
                        TextField(AppConstants.Authenticator.Editor.username, text: $username)
                        AuthenticatorFieldError(message: fieldErrors.username)
                    }
                }
                .disabled(entry == nil && showURIInput)

                if entry == nil {
                    Section(AppConstants.Authenticator.Editor.secretSection) {
                        Toggle(AppConstants.Authenticator.Editor.useURI, isOn: $showURIInput)

                        if showURIInput {
                            VStack(alignment: .leading) {
                                HStack {
                                    TextField(text: $uriString) {
                                        AuthenticatorRequiredFieldLabel(
                                            title: AppConstants.Authenticator.Editor.uri
                                        )
                                    }
                                    ControlGroup {
                                        Button(
                                            AppConstants.Authenticator.Editor.paste,
                                            action: pasteURI
                                        )
                                        Button(
                                            AppConstants.Authenticator.Editor.parse,
                                            action: parseURI
                                        )
                                    }
                                }
                                AuthenticatorFieldError(message: fieldErrors.uri)
                            }
                        } else {
                            VStack(alignment: .leading) {
                                HStack {
                                    TextField(text: $secret) {
                                        AuthenticatorRequiredFieldLabel(
                                            title: AppConstants.Authenticator.Editor.base32Secret
                                        )
                                    }
                                    .font(.system(.body, design: .monospaced))
                                    ControlGroup {
                                        Button(
                                            AppConstants.Authenticator.Editor.paste,
                                            action: pasteSecret
                                        )
                                        Button(
                                            AppConstants.Authenticator.Editor.generate,
                                            action: generateSecret
                                        )
                                    }
                                }
                                AuthenticatorFieldError(message: fieldErrors.secret)
                            }
                        }
                    }
                }

                Section(AppConstants.Authenticator.Editor.optionsSection) {
                    Picker(selection: $algorithm) {
                        ForEach(TOTPAlgorithm.allCases, id: \.self) { algorithm in
                            Text(algorithm.rawValue).tag(algorithm)
                        }
                    } label: {
                        AuthenticatorRequiredFieldLabel(
                            title: AppConstants.Authenticator.Editor.algorithm
                        )
                    }
                    Stepper(
                        value: $digits,
                        in: AppConstants.Authenticator.minimumDigits ...
                            AppConstants.Authenticator.maximumDigits
                    ) {
                        AuthenticatorRequiredFieldLabel(
                            title: String(
                                format: AppConstants.Authenticator.Editor.digitsFormat,
                                digits
                            )
                        )
                    }
                    Stepper(
                        value: $period,
                        in: AppConstants.Authenticator.minimumPeriod ...
                            AppConstants.Authenticator.maximumPeriod,
                        step: AppConstants.Authenticator.periodStep
                    ) {
                        AuthenticatorRequiredFieldLabel(
                            title: String(
                                format: AppConstants.Authenticator.Editor.periodFormat,
                                period
                            )
                        )
                    }
                }
                .disabled(entry == nil && showURIInput)
            }
            .formStyle(.grouped)

            if !globalError.isEmpty {
                Text(globalError)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Divider()

            HStack {
                Spacer()
                Button(AppConstants.Common.cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(
                    entry == nil
                        ? AppConstants.Authenticator.Editor.addTitle
                        : AppConstants.Authenticator.Editor.saveChanges,
                    action: beginSave
                )
                    .disabled(!canSave || isSaving)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(
            minWidth: AppConstants.Authenticator.Editor.width,
            idealWidth: AppConstants.Authenticator.Editor.width,
            maxWidth: AppConstants.Authenticator.Editor.width,
            minHeight: entry == nil
                ? AppConstants.Authenticator.Editor.addMinimumHeight
                : AppConstants.Authenticator.Editor.editMinimumHeight,
            idealHeight: entry == nil
                ? AppConstants.Authenticator.Editor.addIdealHeight
                : AppConstants.Authenticator.Editor.editIdealHeight
        )
        .disabled(isSaving)
        .interactiveDismissDisabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView(AppConstants.Authenticator.Editor.saving)
                    .controlSize(.large)
                    .padding(AppConstants.Authenticator.Editor.progressPadding)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(
                            cornerRadius: AppConstants.Authenticator.Editor.progressCornerRadius
                        )
                    )
                    .allowsHitTesting(true)
            }
        }
        .onChange(of: uriString) { _, _ in
            secret = ""
            parsedURI = nil
            fieldErrors.uri = ""
            globalError = ""
        }
        .onChange(of: showURIInput) { _, usesURI in
            parsedURI = nil
            fieldErrors = EntryFieldErrors()
            globalError = ""
            if usesURI {
                secret = ""
            }
        }
        .onChange(of: serviceName) { _, _ in fieldErrors.serviceName = "" }
        .onChange(of: username) { _, _ in fieldErrors.username = "" }
        .onChange(of: secret) { _, _ in fieldErrors.secret = "" }
    }

    private var canSave: Bool {
        let hasServiceName = !serviceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        if entry != nil { return hasServiceName }
        if showURIInput {
            return parsedURI != nil
        }
        return hasServiceName
            && !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func parseURI() {
        do {
            let parsed = try TOTPEngine.parseOTPAuthURI(uriString)
            parsedURI = parsed
            secret = parsed.base32Secret
            serviceName = parsed.serviceName
            username = parsed.username
            algorithm = parsed.algorithm
            digits = parsed.digits
            period = parsed.period
            fieldErrors = EntryFieldErrors()
            globalError = ""
        } catch {
            parsedURI = nil
            fieldErrors.uri = error.localizedDescription
        }
    }

    private func pasteURI() {
        guard let value = NSPasteboard.general.string(forType: .string) else { return }
        uriString = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pasteSecret() {
        guard let value = NSPasteboard.general.string(forType: .string) else { return }
        secret = value.trimmingCharacters(in: .whitespacesAndNewlines)
        fieldErrors.secret = ""
    }

    private func generateSecret() {
        let key = SymmetricKey(size: .bits256)
        secret = key.withUnsafeBytes { Base32Codec.encode(Data($0)) }
        fieldErrors.secret = ""
    }

    private func beginSave() {
        fieldErrors = EntryFieldErrors()
        globalError = ""
        guard validateFields() else { return }

        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                if var entry {
                    entry.serviceName = serviceName
                    entry.username = username
                    entry.algorithm = algorithm
                    entry.digits = digits
                    entry.period = period
                    try await appState.updateEntry(entry)
                } else if showURIInput {
                    guard let parsedURI else { return }
                    try await appState.addEntry(parsedURI)
                } else {
                    try await appState.addEntry(
                        serviceName: serviceName,
                        username: username,
                        secret: secret,
                        algorithm: algorithm,
                        digits: digits,
                        period: period
                    )
                }
                dismiss()
            } catch {
                globalError = error.localizedDescription
            }
        }
    }

    private func validateFields() -> Bool {
        if entry == nil && showURIInput {
            guard parsedURI != nil else {
                fieldErrors.uri = AppConstants.Authenticator.OTPAuth.invalidURI
                return false
            }
            return true
        }

        let trimmedServiceName = serviceName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmedServiceName.isEmpty {
            fieldErrors.serviceName = AppConstants.Authenticator.Editor.invalidServiceName
            return false
        }
        if trimmedServiceName.contains(AppConstants.Authenticator.labelSeparator) {
            fieldErrors.serviceName =
                AppConstants.Authenticator.Editor.serviceNameContainsSeparator
            return false
        }

        if username.contains(AppConstants.Authenticator.labelSeparator) {
            fieldErrors.username = AppConstants.Authenticator.Editor.usernameContainsSeparator
            return false
        }

        if entry == nil {
            do {
                _ = try Base32Codec.decode(secret)
            } catch {
                fieldErrors.secret = error.localizedDescription
                return false
            }
        }

        return true
    }
}
