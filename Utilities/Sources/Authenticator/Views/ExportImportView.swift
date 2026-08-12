import SwiftUI
import UniformTypeIdentifiers

struct ExportImportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var isSuccess = false
    @State private var showExport = false
    @State private var showImport = false
    @State private var exportDocument: OTPAuthDocument?
    @State private var isImporting = false

    var body: some View {
        VStack(spacing: AppConstants.Authenticator.Transfer.stackSpacing) {
            HStack {
                Text(AppConstants.Authenticator.Transfer.title).font(.headline)
                Spacer()
                Button(AppConstants.Authenticator.Transfer.done) { dismiss() }
            }
            .padding()

            Divider()

            VStack(spacing: AppConstants.Authenticator.Transfer.contentSpacing) {
                VStack(
                    alignment: .leading,
                    spacing: AppConstants.Authenticator.Transfer.descriptionSpacing
                ) {
                    Label(
                        AppConstants.Authenticator.Transfer.exportDescription,
                        systemImage: "doc.plaintext"
                    )
                    Label(
                        AppConstants.Authenticator.Transfer.secretWarning,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(
                    Color.secondary.opacity(
                        AppConstants.Authenticator.Transfer.descriptionOpacity
                    )
                )
                .cornerRadius(AppConstants.Authenticator.Transfer.descriptionCornerRadius)
                .padding(.horizontal)

                HStack(spacing: AppConstants.Authenticator.Transfer.buttonsSpacing) {
                    Button(action: prepareExport) {
                        Label(
                            AppConstants.Authenticator.Transfer.export,
                            systemImage: "square.and.arrow.up"
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button { showImport = true } label: {
                        Label(
                            AppConstants.Authenticator.Transfer.`import`,
                            systemImage: "square.and.arrow.down"
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)

                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(isSuccess ? .green : .red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .frame(
            width: AppConstants.Authenticator.Transfer.width,
            height: AppConstants.Authenticator.Transfer.height
        )
        .disabled(isImporting)
        .interactiveDismissDisabled(isImporting)
        .overlay {
            if isImporting {
                ZStack {
                    Rectangle()
                        .fill(
                            .black.opacity(AppConstants.Authenticator.Transfer.overlayOpacity)
                        )
                        .ignoresSafeArea()
                    ProgressView(AppConstants.Authenticator.Transfer.importing)
                        .controlSize(.large)
                        .padding(AppConstants.Authenticator.Transfer.progressPadding)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(
                                cornerRadius: AppConstants.Authenticator.Transfer.progressCornerRadius
                            )
                        )
                }
                .allowsHitTesting(true)
            }
        }
        .fileExporter(
            isPresented: $showExport,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: AppConstants.Authenticator.Transfer.exportFilename
        ) { result in
            switch result {
            case .success:
                message = AppConstants.Authenticator.Transfer.exportSucceeded
                isSuccess = true
            case .failure(let error):
                message = error.localizedDescription
                isSuccess = false
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showImport,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false,
            onCompletion: importFile
        )
    }

    private func prepareExport() {
        do {
            exportDocument = OTPAuthDocument(data: try appState.exportData())
            showExport = true
        } catch {
            message = error.localizedDescription
            isSuccess = false
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        let url: URL
        do {
            let urls = try result.get()
            guard let selectedURL = urls.first else { return }
            url = selectedURL
        } catch {
            message = error.localizedDescription
            isSuccess = false
            return
        }

        isImporting = true
        message = ""
        Task {
            defer { isImporting = false }
            do {
                let candidates = try await Task.detached(priority: .userInitiated) {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessed { url.stopAccessingSecurityScopedResource() }
                    }

                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    if let fileSize = values.fileSize,
                       fileSize > AppConstants.Authenticator.OTPAuth.maximumFileSize {
                        throw OTPAuthImportParser.ImportError.fileTooLarge
                    }
                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    return try OTPAuthImportParser.parse(data)
                }.value
                let importedCount = try await appState.importEntries(candidates)
                message = String(
                    format: AppConstants.Authenticator.Transfer.importSucceededFormat,
                    importedCount
                )
                isSuccess = true
            } catch {
                message = error.localizedDescription
                isSuccess = false
            }
        }
    }
}

struct OTPAuthDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]

    private let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
