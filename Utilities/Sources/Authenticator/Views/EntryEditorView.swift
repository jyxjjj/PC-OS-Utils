import SwiftUI
import CryptoKit

private struct AuthenticatorRequiredFieldLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
            Text("*").foregroundStyle(.red)
        }
    }
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
    @State private var errorMessage = ""
    @State private var isSaving = false

    init(entry: TOTPEntry? = nil) {
        self.entry = entry
        _serviceName = State(initialValue: entry?.serviceName ?? "")
        _username = State(initialValue: entry?.username ?? "")
        _algorithm = State(initialValue: entry?.algorithm ?? .sha1)
        _digits = State(initialValue: entry?.digits ?? 6)
        _period = State(initialValue: entry?.period ?? 30)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(entry == nil ? "添加账户" : "编辑账户")
                    .font(.headline)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                Section("账户信息") {
                    TextField(text: $serviceName, prompt: Text("例如 GitHub")) {
                        AuthenticatorRequiredFieldLabel(title: "服务名称")
                    }
                    TextField("用户名或备注", text: $username)
                }
                .disabled(entry == nil && showURIInput)

                if entry == nil {
                    Section("密钥") {
                        Toggle("改为粘贴 otpauth:// URI", isOn: $showURIInput)

                        if showURIInput {
                            HStack {
                                TextField(text: $uriString) {
                                    AuthenticatorRequiredFieldLabel(title: "otpauth:// URI")
                                }
                                PasteButton(payloadType: String.self, onPaste: pasteURI)
                                    .buttonStyle(.bordered)
                                Button("解析", action: parseURI)
                                    .buttonStyle(.bordered)
                            }
                        } else {
                            HStack {
                                TextField(text: $secret) {
                                    AuthenticatorRequiredFieldLabel(title: "Base32 密钥")
                                }
                                .font(.system(.body, design: .monospaced))
                                PasteButton(payloadType: String.self, onPaste: pasteSecret)
                                    .buttonStyle(.bordered)
                                Button("生成", action: generateSecret)
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section("选项") {
                    Picker(selection: $algorithm) {
                        ForEach(TOTPAlgorithm.allCases, id: \.self) { algorithm in
                            Text(algorithm.rawValue).tag(algorithm)
                        }
                    } label: {
                        AuthenticatorRequiredFieldLabel(title: "算法")
                    }
                    Stepper(value: $digits, in: 6...8) {
                        AuthenticatorRequiredFieldLabel(title: "位数: \(digits)")
                    }
                    Stepper(value: $period, in: 15...60, step: 15) {
                        AuthenticatorRequiredFieldLabel(title: "周期: \(period) 秒")
                    }
                }
                .disabled(entry == nil && showURIInput)
            }
            .formStyle(.grouped)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Divider()

            HStack {
                Spacer()
                Button(entry == nil ? "添加账户" : "保存更改", action: beginSave)
                    .disabled(!canSave || isSaving)
                    .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(
            width: entry == nil ? 420 : 380,
            height: entry == nil ? 520 : 380
        )
        .disabled(isSaving)
        .interactiveDismissDisabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView("正在保存…")
                    .controlSize(.large)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(true)
            }
        }
        .onChange(of: uriString) { _, _ in
            secret = ""
            parsedURI = nil
            errorMessage = ""
        }
        .onChange(of: showURIInput) { _, usesURI in
            parsedURI = nil
            errorMessage = ""
            if usesURI {
                secret = ""
            }
        }
    }

    private var canSave: Bool {
        let hasServiceName = !serviceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        if entry != nil { return hasServiceName }
        if showURIInput {
            return parsedURI != nil
        }
        return hasServiceName && (try? Base32Codec.decode(secret)) != nil
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
            errorMessage = ""
        } catch {
            let message = error.localizedDescription
            parsedURI = nil
            errorMessage = message
        }
    }

    private func pasteURI(_ values: [String]) {
        guard let value = values.first else { return }
        uriString = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pasteSecret(_ values: [String]) {
        guard let value = values.first else { return }
        secret = value.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = ""
    }

    private func generateSecret() {
        let key = SymmetricKey(size: .bits256)
        secret = key.withUnsafeBytes { Base32Codec.encode(Data($0)) }
        errorMessage = ""
    }

    private func beginSave() {
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
                errorMessage = error.localizedDescription
            }
        }
    }
}
