import CommonCrypto
import CryptoKit
import Foundation
import SwiftData

@Model
final class AuthenticatorConfiguration {
    var salt: Data
    var rounds: Int
    var sealedVerifier: Data

    init(salt: Data, rounds: Int, sealedVerifier: Data) {
        self.salt = salt
        self.rounds = rounds
        self.sealedVerifier = sealedVerifier
    }
}

@Model
final class EncryptedTOTPRecord {
    @Attribute(.unique) var id: UUID
    var sortPosition: Int
    var sealedPayload: Data

    init(id: UUID, sortPosition: Int, sealedPayload: Data) {
        self.id = id
        self.sortPosition = sortPosition
        self.sealedPayload = sealedPayload
    }
}

nonisolated private struct EncryptedRecordSnapshot: Sendable {
    let id: UUID
    let sortPosition: Int
    let sealedPayload: Data
}

nonisolated private struct SealedEntry: Sendable {
    let id: UUID
    let payload: Data
}

nonisolated private struct UnlockResult: Sendable {
    let key: SymmetricKey
    let entries: [TOTPEntry]
}

nonisolated private struct SetupResult: Sendable {
    let key: SymmetricKey
    let salt: Data
    let rounds: Int
    let sealedVerifier: Data
}

nonisolated private enum AuthenticatorCrypto {
    static func setup(password: Data) throws -> SetupResult {
        let salt = randomSalt()
        let rounds = try calibratedRounds(passwordLength: password.count)
        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        return SetupResult(
            key: key,
            salt: salt,
            rounds: rounds,
            sealedVerifier: try seal(Data(), using: key)
        )
    }

    static func unlock(
        password: Data,
        salt: Data,
        rounds: Int,
        sealedVerifier: Data,
        records: [EncryptedRecordSnapshot]
    ) throws -> UnlockResult {
        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        do {
            let verifier = try AES.GCM.SealedBox(combined: sealedVerifier)
            _ = try AES.GCM.open(verifier, using: key)
        } catch {
            throw AuthenticatorStoreError.authenticationFailed
        }

        var sortPositions = Set<Int>()
        sortPositions.reserveCapacity(records.count)
        for record in records {
            guard sortPositions.insert(record.sortPosition).inserted else {
                throw AuthenticatorStoreError.invalidOrder
            }
        }
        let entries: [TOTPEntry]
        do {
            let decoder = PropertyListDecoder()
            entries = try records.map { record in
                let box = try AES.GCM.SealedBox(combined: record.sealedPayload)
                let payload = try AES.GCM.open(
                    box,
                    using: key,
                    authenticating: Data(record.id.uuidString.utf8)
                )
                let entry = try decoder.decode(TOTPEntry.self, from: payload)
                guard entry.id == record.id else {
                    throw AuthenticatorStoreError.invalidStore
                }
                return entry
            }
        } catch let error as AuthenticatorStoreError {
            throw error
        } catch {
            throw AuthenticatorStoreError.invalidStore
        }
        return UnlockResult(key: key, entries: entries)
    }

    static func sealEntry(
        _ entry: TOTPEntry,
        using key: SymmetricKey
    ) throws -> SealedEntry {
        try sealEntry(entry, using: key, encoder: PropertyListEncoder())
    }

    static func sealEntries(
        _ entries: [TOTPEntry],
        using key: SymmetricKey
    ) throws -> [SealedEntry] {
        let encoder = PropertyListEncoder()
        return try entries.map { entry in
            try sealEntry(entry, using: key, encoder: encoder)
        }
    }

    private static func sealEntry(
        _ entry: TOTPEntry,
        using key: SymmetricKey,
        encoder: PropertyListEncoder
    ) throws -> SealedEntry {
        let payload = try encoder.encode(entry)
        return SealedEntry(
            id: entry.id,
            payload: try seal(
                payload,
                using: key,
                authenticating: Data(entry.id.uuidString.utf8)
            )
        )
    }

    private static func calibratedRounds(passwordLength: Int) throws -> Int {
        let rounds = CCCalibratePBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordLength,
            AppConstants.Authenticator.Store.saltSize,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            AppConstants.Authenticator.Store.keySize,
            AppConstants.Authenticator.Store.derivationMilliseconds
        )
        guard rounds != UInt32.max else {
            throw AuthenticatorStoreError.keyDerivationFailed
        }
        return Int(rounds)
    }

    private static func deriveKey(
        password: Data,
        salt: Data,
        rounds: Int
    ) throws -> SymmetricKey {
        guard let roundCount = UInt32(exactly: rounds), roundCount > 0 else {
            throw AuthenticatorStoreError.invalidParameters
        }
        var keyBytes = [UInt8](
            repeating: 0,
            count: AppConstants.Authenticator.Store.keySize
        )
        let status = password.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.bindMemory(to: Int8.self).baseAddress,
                    password.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    roundCount,
                    &keyBytes,
                    keyBytes.count
                )
            }
        }
        guard status == kCCSuccess else {
            throw AuthenticatorStoreError.keyDerivationFailed
        }
        return SymmetricKey(data: keyBytes)
    }

    private static func randomSalt() -> Data {
        let randomKey = SymmetricKey(size: .bits256)
        return randomKey.withUnsafeBytes {
            Data($0.prefix(AppConstants.Authenticator.Store.saltSize))
        }
    }

    private static func seal(
        _ payload: Data,
        using key: SymmetricKey,
        authenticating authenticatedData: Data? = nil
    ) throws -> Data {
        let box =
            if let authenticatedData {
                try AES.GCM.seal(payload, using: key, authenticating: authenticatedData)
            } else {
                try AES.GCM.seal(payload, using: key)
            }
        guard let combined = box.combined else {
            throw AuthenticatorStoreError.encryptionFailed
        }
        return combined
    }
}

@MainActor
final class AuthenticatorStore {
    private var container: ModelContainer?
    private var key: SymmetricKey?
    private var keyGeneration = 0

    func hasEncryptedData() throws -> Bool {
        let context = try context()
        let configurationCount = try context.fetchCount(
            FetchDescriptor<AuthenticatorConfiguration>()
        )
        guard configurationCount <= 1 else {
            throw AuthenticatorStoreError.invalidStore
        }
        if configurationCount == 0 {
            let entryCount = try context.fetchCount(FetchDescriptor<EncryptedTOTPRecord>())
            guard entryCount == 0 else {
                throw AuthenticatorStoreError.invalidStore
            }
        }
        return configurationCount != 0
    }

    func unlock(with userKey: String) async throws -> [TOTPEntry] {
        let normalizedKey = userKey.precomposedStringWithCanonicalMapping
        guard !normalizedKey.isEmpty else {
            throw AuthenticatorStoreError.emptyKey
        }
        let password = Data(normalizedKey.utf8)
        let generation = keyGeneration
        let context = try context()
        let configurations = try context.fetch(
            FetchDescriptor<AuthenticatorConfiguration>()
        )
        guard configurations.count <= 1 else {
            throw AuthenticatorStoreError.invalidStore
        }

        if let configuration = configurations.first {
            let descriptor = FetchDescriptor<EncryptedTOTPRecord>(
                sortBy: [SortDescriptor(\.sortPosition)]
            )
            let records = try context.fetch(descriptor).map {
                EncryptedRecordSnapshot(
                    id: $0.id,
                    sortPosition: $0.sortPosition,
                    sealedPayload: $0.sealedPayload
                )
            }
            let salt = configuration.salt
            let rounds = configuration.rounds
            let sealedVerifier = configuration.sealedVerifier
            let result = try await Task.detached(priority: .userInitiated) {
                try AuthenticatorCrypto.unlock(
                    password: password,
                    salt: salt,
                    rounds: rounds,
                    sealedVerifier: sealedVerifier,
                    records: records
                )
            }.value
            guard keyGeneration == generation else {
                throw AuthenticatorStoreError.locked
            }
            key = result.key
            keyGeneration += 1
            return result.entries
        }

        guard try context.fetchCount(FetchDescriptor<EncryptedTOTPRecord>()) == 0 else {
            throw AuthenticatorStoreError.invalidStore
        }
        let setup = try await Task.detached(priority: .userInitiated) {
            try AuthenticatorCrypto.setup(password: password)
        }.value
        guard keyGeneration == generation else {
            throw AuthenticatorStoreError.locked
        }
        try transaction(in: context) {
            context.insert(
                AuthenticatorConfiguration(
                    salt: setup.salt,
                    rounds: setup.rounds,
                    sealedVerifier: setup.sealedVerifier
                )
            )
        }
        key = setup.key
        keyGeneration += 1
        return []
    }

    func add(_ entries: [TOTPEntry]) async throws {
        guard !entries.isEmpty else { return }
        guard let key else { throw AuthenticatorStoreError.locked }
        let generation = keyGeneration
        let sealedEntries = try await Task.detached(priority: .userInitiated) {
            try AuthenticatorCrypto.sealEntries(entries, using: key)
        }.value
        guard self.key != nil, keyGeneration == generation else {
            throw AuthenticatorStoreError.locked
        }

        let context = try context()
        try transaction(in: context) {
            var descriptor = FetchDescriptor<EncryptedTOTPRecord>()
            descriptor.propertiesToFetch = [\EncryptedTOTPRecord.id, \EncryptedTOTPRecord.sortPosition]
            let records = try context.fetch(descriptor)
            var seenIDs = Set<UUID>()
            seenIDs.reserveCapacity(records.count + sealedEntries.count)
            var maximumPosition = -1
            for record in records {
                seenIDs.insert(record.id)
                maximumPosition = max(maximumPosition, record.sortPosition)
            }
            for entry in sealedEntries {
                guard seenIDs.insert(entry.id).inserted else {
                    throw AuthenticatorStoreError.duplicateEntries
                }
            }

            var position = maximumPosition + 1
            for entry in sealedEntries {
                context.insert(
                    EncryptedTOTPRecord(
                        id: entry.id,
                        sortPosition: position,
                        sealedPayload: entry.payload
                    )
                )
                position += 1
            }
        }
    }

    func update(_ entry: TOTPEntry) async throws {
        guard let key else { throw AuthenticatorStoreError.locked }
        let generation = keyGeneration
        let sealedEntry = try await Task.detached(priority: .userInitiated) {
            try AuthenticatorCrypto.sealEntry(entry, using: key)
        }.value
        guard self.key != nil, keyGeneration == generation else {
            throw AuthenticatorStoreError.locked
        }

        let context = try context()
        try transaction(in: context) {
            let record = try record(id: entry.id, in: context)
            record.sealedPayload = sealedEntry.payload
        }
    }

    func delete(id: UUID) throws {
        guard key != nil else { throw AuthenticatorStoreError.locked }
        let context = try context()
        try transaction(in: context) {
            context.delete(try record(id: id, in: context))
        }
    }

    func reorder(ids orderedIDs: [UUID]) throws {
        guard key != nil else { throw AuthenticatorStoreError.locked }
        let context = try context()
        try transaction(in: context) {
            var descriptor = FetchDescriptor<EncryptedTOTPRecord>(
                sortBy: [SortDescriptor(\.sortPosition)]
            )
            descriptor.propertiesToFetch = [\EncryptedTOTPRecord.id, \EncryptedTOTPRecord.sortPosition]
            let records = try context.fetch(descriptor)
            guard records.count == orderedIDs.count else {
                throw AuthenticatorStoreError.invalidOrder
            }
            guard !records.elementsEqual(orderedIDs, by: { $0.id == $1 }) else { return }

            var recordsByID = Dictionary(
                uniqueKeysWithValues: records.lazy.map { ($0.id, $0) }
            )
            for (position, id) in orderedIDs.enumerated() {
                guard let record = recordsByID.removeValue(forKey: id) else {
                    throw AuthenticatorStoreError.invalidOrder
                }
                if record.sortPosition != position {
                    record.sortPosition = position
                }
            }
            guard recordsByID.isEmpty else {
                throw AuthenticatorStoreError.invalidOrder
            }
        }
    }

    func lock() {
        key = nil
        keyGeneration += 1
    }

    private func record(id: UUID, in context: ModelContext) throws -> EncryptedTOTPRecord {
        let descriptor = FetchDescriptor<EncryptedTOTPRecord>(
            predicate: #Predicate { $0.id == id }
        )
        let records = try context.fetch(descriptor)
        guard records.count == 1, let record = records.first else {
            throw AuthenticatorStoreError.missingEntry
        }
        return record
    }

    private func transaction(
        in context: ModelContext,
        _ changes: () throws -> Void
    ) throws {
        do {
            try changes()
            guard context.hasChanges else { return }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func context() throws -> ModelContext {
        if let container { return container.mainContext }
        let schema = Schema([
            AuthenticatorConfiguration.self,
            EncryptedTOTPRecord.self,
        ])
        let configuration = ModelConfiguration(
            AppConstants.Authenticator.Store.modelConfigurationName,
            schema: schema,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        let created = try ModelContainer(for: schema, configurations: configuration)
        created.mainContext.autosaveEnabled = false
        container = created
        return created.mainContext
    }
}

nonisolated enum AuthenticatorStoreError: Error, LocalizedError, Sendable {
    case authenticationFailed
    case duplicateEntries
    case encryptionFailed
    case invalidOrder
    case invalidParameters
    case invalidStore
    case keyDerivationFailed
    case emptyKey
    case locked
    case missingEntry

    var errorDescription: String? {
        switch self {
            case .authenticationFailed: AppConstants.Authenticator.Store.authenticationFailed
            case .duplicateEntries: AppConstants.Authenticator.Store.duplicateEntries
            case .encryptionFailed: AppConstants.Authenticator.Store.encryptionFailed
            case .invalidOrder: AppConstants.Authenticator.Store.invalidOrder
            case .invalidParameters: AppConstants.Authenticator.Store.invalidParameters
            case .invalidStore: AppConstants.Authenticator.Store.invalidStore
            case .keyDerivationFailed: AppConstants.Authenticator.Store.keyDerivationFailed
            case .emptyKey: AppConstants.Authenticator.Store.emptyKey
            case .locked: AppConstants.Authenticator.Store.locked
            case .missingEntry: AppConstants.Authenticator.Store.missingEntry
        }
    }
}
