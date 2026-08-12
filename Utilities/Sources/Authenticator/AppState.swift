import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private let store = AuthenticatorStore()

    private(set) var initializationError: String?
    private(set) var isConfigured = false
    private(set) var isUnlocked = false
    private(set) var entries: [TOTPEntry] = []

    init() {
        initialize()
    }

    func initialize() {
        do {
            isConfigured = try store.hasEncryptedData()
            initializationError = nil
        } catch {
            initializationError = error.localizedDescription
        }
    }

    func unlock(with userKey: String) async throws {
        entries = try await store.unlock(with: userKey)
        isConfigured = true
        isUnlocked = true
        initializationError = nil
    }

    func lock() {
        store.lock()
        entries = []
        isUnlocked = false
    }

    // MARK: - Entry management

    func addEntry(serviceName: String, username: String, secret: String,
                  algorithm: TOTPAlgorithm, digits: Int, period: Int) async throws {
        let trimmedServiceName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServiceName.isEmpty else { throw AuthError.emptyServiceName }
        guard !trimmedServiceName.contains(AppConstants.Authenticator.labelSeparator),
              !trimmedUsername.contains(AppConstants.Authenticator.labelSeparator) else {
            throw AuthError.invalidLabel
        }
        guard (AppConstants.Authenticator.minimumDigits ...
               AppConstants.Authenticator.maximumDigits).contains(digits),
              AppConstants.Authenticator.supportedPeriods.contains(period) else {
            throw AuthError.invalidParameters
        }
        let secretData = try Base32Codec.decode(secret)
        try await addEntry(
            serviceName: trimmedServiceName,
            username: trimmedUsername,
            secret: secretData,
            algorithm: algorithm,
            digits: digits,
            period: period
        )
    }

    func addEntry(_ parameters: OTPAuthParameters) async throws {
        try await addEntry(
            serviceName: parameters.serviceName,
            username: parameters.username,
            secret: parameters.secret,
            algorithm: parameters.algorithm,
            digits: parameters.digits,
            period: parameters.period
        )
    }

    private func addEntry(
        serviceName: String,
        username: String,
        secret: Data,
        algorithm: TOTPAlgorithm,
        digits: Int,
        period: Int
    ) async throws {
        guard !serviceName.isEmpty else { throw AuthError.emptyServiceName }
        guard !serviceName.contains(AppConstants.Authenticator.labelSeparator),
              !username.contains(AppConstants.Authenticator.labelSeparator) else {
            throw AuthError.invalidLabel
        }
        guard (AppConstants.Authenticator.minimumDigits ...
               AppConstants.Authenticator.maximumDigits).contains(digits),
              AppConstants.Authenticator.supportedPeriods.contains(period) else {
            throw AuthError.invalidParameters
        }
        let entry = TOTPEntry(
            id: UUID(),
            serviceName: serviceName,
            username: username,
            secret: secret,
            algorithm: algorithm,
            digits: digits,
            period: period
        )
        try await store.add([entry])
        entries.append(entry)
    }

    func updateEntry(_ entry: TOTPEntry) async throws {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw AuthError.entryNotFound
        }
        var normalizedEntry = entry
        normalizedEntry.serviceName = entry.serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedEntry.username = entry.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEntry.serviceName.isEmpty else { throw AuthError.emptyServiceName }
        guard !normalizedEntry.serviceName.contains(AppConstants.Authenticator.labelSeparator),
              !normalizedEntry.username.contains(AppConstants.Authenticator.labelSeparator) else {
            throw AuthError.invalidLabel
        }
        guard (AppConstants.Authenticator.minimumDigits ...
               AppConstants.Authenticator.maximumDigits).contains(normalizedEntry.digits),
              AppConstants.Authenticator.supportedPeriods.contains(normalizedEntry.period) else {
            throw AuthError.invalidParameters
        }
        guard entries[index] != normalizedEntry else { return }
        try await store.update(normalizedEntry)
        entries[index] = normalizedEntry
    }

    func deleteEntry(id: UUID) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw AuthError.entryNotFound
        }
        try store.delete(id: id)
        entries.remove(at: index)
    }

    func reorderEntries(ids orderedIDs: [UUID]) throws {
        guard orderedIDs.count == entries.count else {
            throw AuthError.invalidOrder
        }
        guard !entries.elementsEqual(orderedIDs, by: { $0.id == $1 }) else { return }

        var entriesByID = Dictionary(
            uniqueKeysWithValues: entries.lazy.map { ($0.id, $0) }
        )
        var next: [TOTPEntry] = []
        next.reserveCapacity(entries.count)

        for id in orderedIDs {
            guard let entry = entriesByID.removeValue(forKey: id) else {
                throw AuthError.invalidOrder
            }
            next.append(entry)
        }
        guard entriesByID.isEmpty else { throw AuthError.invalidOrder }
        try store.reorder(ids: orderedIDs)
        entries = next
    }

    // MARK: - OTP Auth URI export / import

    func exportData() throws -> Data {
        let uriLines = try entries.map(OTPAuthURIBuilder.make)
        return Data(
            uriLines.joined(separator: AppConstants.Authenticator.OTPAuth.lineSeparator).utf8
        )
    }

    @discardableResult
    func importEntries(_ candidates: [TOTPEntry]) async throws -> Int {
        let currentEntries = entries
        try await Task.detached(priority: .userInitiated) {
            var existing = Set<String>()
            existing.reserveCapacity(currentEntries.count + candidates.count)
            for entry in currentEntries {
                existing.insert(try OTPAuthURIBuilder.make(entry))
            }
            for entry in candidates {
                let normalized = try OTPAuthURIBuilder.make(entry)
                guard existing.insert(normalized).inserted else {
                    throw OTPAuthImportParser.ImportError.duplicateAccount
                }
            }
        }.value
        try await store.add(candidates)
        entries.append(contentsOf: candidates)
        return candidates.count
    }

    nonisolated enum AuthError: Error, LocalizedError, Sendable {
        case entryNotFound
        case invalidOrder
        case emptyServiceName
        case invalidLabel
        case invalidParameters

        var errorDescription: String? {
            switch self {
            case .entryNotFound: return AppConstants.Authenticator.State.entryNotFound
            case .invalidOrder: return AppConstants.Authenticator.State.invalidOrder
            case .emptyServiceName: return AppConstants.Authenticator.State.emptyServiceName
            case .invalidLabel: return AppConstants.Authenticator.State.invalidLabel
            case .invalidParameters: return AppConstants.Authenticator.State.invalidParameters
            }
        }
    }

    nonisolated enum ExportError: Error, LocalizedError, Sendable {
        case invalidAccount

        var errorDescription: String? {
            AppConstants.Authenticator.OTPAuth.invalidAccount
        }
    }

}

nonisolated enum OTPAuthURIBuilder {
    static func make(_ entry: TOTPEntry) throws -> String {
        guard !entry.serviceName.contains(AppConstants.Authenticator.labelSeparator),
              !entry.username.contains(AppConstants.Authenticator.labelSeparator) else {
            throw AppState.AuthError.invalidLabel
        }
        var components = URLComponents()
        components.scheme = AppConstants.Authenticator.OTPAuth.scheme
        components.host = AppConstants.Authenticator.OTPAuth.host
        components.path = entry.username.isEmpty
            ? String(
                format: AppConstants.Authenticator.OTPAuth.servicePathFormat,
                entry.serviceName
            )
            : String(
                format: AppConstants.Authenticator.OTPAuth.accountPathFormat,
                entry.serviceName,
                entry.username
            )
        components.queryItems = [
            URLQueryItem(
                name: AppConstants.Authenticator.OTPAuth.secretQueryName,
                value: Base32Codec.encode(entry.secret)
            ),
            URLQueryItem(
                name: AppConstants.Authenticator.OTPAuth.issuerQueryName,
                value: entry.serviceName
            ),
            URLQueryItem(
                name: AppConstants.Authenticator.OTPAuth.algorithmQueryName,
                value: entry.algorithm.rawValue
            ),
            URLQueryItem(
                name: AppConstants.Authenticator.OTPAuth.digitsQueryName,
                value: String(entry.digits)
            ),
            URLQueryItem(
                name: AppConstants.Authenticator.OTPAuth.periodQueryName,
                value: String(entry.period)
            ),
        ]
        guard let uri = components.string else {
            throw AppState.ExportError.invalidAccount
        }
        return uri
    }
}

nonisolated enum OTPAuthImportParser {
    static func parse(_ fileData: Data) throws -> [TOTPEntry] {
        guard fileData.count <= AppConstants.Authenticator.OTPAuth.maximumFileSize else {
            throw ImportError.fileTooLarge
        }
        guard let contents = String(data: fileData, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }

        var entries: [TOTPEntry] = []
        for rawLine in contents.split(whereSeparator: \Character.isNewline) {
            let uri = rawLine.trimmingCharacters(in: .whitespaces)
            guard !uri.isEmpty else { continue }
            let parsed = try TOTPEngine.parseOTPAuthURI(uri)
            entries.append(TOTPEntry(
                id: UUID(),
                serviceName: parsed.serviceName,
                username: parsed.username,
                secret: parsed.secret,
                algorithm: parsed.algorithm,
                digits: parsed.digits,
                period: parsed.period
            ))
        }
        guard !entries.isEmpty else { throw ImportError.noAccounts }
        return entries
    }

    enum ImportError: Error, LocalizedError, Sendable {
        case fileTooLarge
        case invalidEncoding
        case noAccounts
        case duplicateAccount

        var errorDescription: String? {
            switch self {
            case .fileTooLarge: AppConstants.Authenticator.OTPAuth.fileTooLarge
            case .invalidEncoding: AppConstants.Authenticator.OTPAuth.invalidEncoding
            case .noAccounts: AppConstants.Authenticator.OTPAuth.noAccounts
            case .duplicateAccount: AppConstants.Authenticator.OTPAuth.duplicateAccount
            }
        }
    }
}
