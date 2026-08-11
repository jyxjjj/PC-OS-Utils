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
        guard !trimmedServiceName.contains(":"), !trimmedUsername.contains(":") else {
            throw AuthError.invalidLabel
        }
        guard (6 ... 8).contains(digits), TOTPEngine.supportedPeriods.contains(period) else {
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
        guard !serviceName.contains(":"), !username.contains(":") else {
            throw AuthError.invalidLabel
        }
        guard (6 ... 8).contains(digits), TOTPEngine.supportedPeriods.contains(period) else {
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
        guard !normalizedEntry.serviceName.contains(":"), !normalizedEntry.username.contains(":") else {
            throw AuthError.invalidLabel
        }
        guard (6 ... 8).contains(normalizedEntry.digits),
              TOTPEngine.supportedPeriods.contains(normalizedEntry.period) else {
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
        return Data(uriLines.joined(separator: "\n").utf8)
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
            case .entryNotFound: return "未找到账户"
            case .invalidOrder: return "账户排序数据无效"
            case .emptyServiceName: return "服务名称不能为空"
            case .invalidLabel: return "服务名称和用户名不能包含冒号"
            case .invalidParameters: return "验证码位数或周期无效"
            }
        }
    }

    nonisolated enum ExportError: Error, LocalizedError, Sendable {
        case invalidAccount

        var errorDescription: String? {
            "无法创建 OTP Auth URI"
        }
    }

}

nonisolated enum OTPAuthURIBuilder {
    static func make(_ entry: TOTPEntry) throws -> String {
        guard !entry.serviceName.contains(":"), !entry.username.contains(":") else {
            throw AppState.AuthError.invalidLabel
        }
        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = "totp"
        components.path = entry.username.isEmpty
            ? "/\(entry.serviceName)"
            : "/\(entry.serviceName):\(entry.username)"
        components.queryItems = [
            URLQueryItem(name: "secret", value: Base32Codec.encode(entry.secret)),
            URLQueryItem(name: "issuer", value: entry.serviceName),
            URLQueryItem(name: "algorithm", value: entry.algorithm.rawValue),
            URLQueryItem(name: "digits", value: String(entry.digits)),
            URLQueryItem(name: "period", value: String(entry.period)),
        ]
        guard let uri = components.string else {
            throw AppState.ExportError.invalidAccount
        }
        return uri
    }
}

nonisolated enum OTPAuthImportParser {
    static let maximumFileSize = 1_048_576

    static func parse(_ fileData: Data) throws -> [TOTPEntry] {
        guard fileData.count <= maximumFileSize else {
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
            case .fileTooLarge: "导入文件不能超过 1 MiB"
            case .invalidEncoding: "导入文件必须是 UTF-8 文本"
            case .noAccounts: "导入文件中不包含 OTP Auth URI"
            case .duplicateAccount: "导入文件包含重复或已存在的账户"
            }
        }
    }
}
