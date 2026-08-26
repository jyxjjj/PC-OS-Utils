import Foundation

actor CodexSessionScanner {
    private let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        formatter.isLenient = false
        return formatter
    }()

    private struct CacheEntry {
        let size: Int
        let modifiedAt: Date
        let session: CodexSession?
        let isComplete: Bool
    }

    private var cache: [URL: CacheEntry] = [:]

    func loadIndex(_ directory: URL) async throws -> [CodexSessionIndexEntry] {
        let url = directory.appendingPathComponent(AppConstants.Codex.sessionIndexFile)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let length = try handle.seekToEnd()
        var endsWithNewline = true
        if length > 0 {
            try handle.seek(toOffset: length - 1)
            endsWithNewline = try handle.read(upToCount: 1) == Data([0x0A])
        }
        try handle.seek(toOffset: 0)

        let decoder = JSONDecoder()
        var entriesByID: [String: CodexSessionIndexEntry] = [:]
        var pendingLine: String?
        for try await line in handle.bytes.lines {
            try Task.checkCancellation()
            if let pendingLine {
                let entry = try decoder.decode(
                    CodexSessionIndexEntry.self,
                    from: Data(pendingLine.utf8)
                )
                if let existing = entriesByID[entry.id] {
                    if existing.updatedAt < entry.updatedAt {
                        entriesByID[entry.id] = entry
                    }
                } else {
                    entriesByID[entry.id] = entry
                }
            }
            pendingLine = line
        }
        if endsWithNewline, let pendingLine {
            let entry = try decoder.decode(
                CodexSessionIndexEntry.self,
                from: Data(pendingLine.utf8)
            )
            if let existing = entriesByID[entry.id] {
                if existing.updatedAt < entry.updatedAt {
                    entriesByID[entry.id] = entry
                }
            } else {
                entriesByID[entry.id] = entry
            }
        }
        return entriesByID.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func scanThread(_ directory: URL, focusedID: String) async throws -> CodexScanResult {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]
        var files: [(URL, URLResourceValues)] = []
        var unreadableFiles: [CodexUnreadableFile] = []
        for name in AppConstants.Codex.allowedSessionDirectories {
            let sessionsDirectory = directory.appendingPathComponent(name, isDirectory: true)
            guard FileManager.default.fileExists(atPath: sessionsDirectory.path) else { continue }
            let directoryValues = try sessionsDirectory.resourceValues(forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ])
            guard directoryValues.isDirectory == true,
                directoryValues.isSymbolicLink != true,
                let enumerator = FileManager.default.enumerator(
                    at: sessionsDirectory,
                    includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
            else {
                throw CodexScanError.cannotEnumerate
            }

            while let url = enumerator.nextObject() as? URL {
                try Task.checkCancellation()
                guard url.pathExtension == "jsonl" else { continue }
                do {
                    let values = try url.resourceValues(forKeys: keys)
                    guard values.isRegularFile == true,
                        values.isSymbolicLink != true
                    else { continue }
                    files.append((url, values))
                } catch {
                    unreadableFiles.append(
                        CodexUnreadableFile(
                            url: url,
                            reason: error.localizedDescription
                        ))
                }
            }
        }

        let currentFiles = Set(files.map(\.0))
        cache = cache.filter { currentFiles.contains($0.key) }

        var sessions: [CodexSession] = []
        for (url, values) in files {
            try Task.checkCancellation()
            guard let size = values.fileSize, let modifiedAt = values.contentModificationDate else {
                unreadableFiles.append(
                    CodexUnreadableFile(
                        url: url,
                        reason: AppConstants.Codex.missingFileAttributes
                    ))
                continue
            }
            if let cached = cache[url], cached.size == size, cached.modifiedAt == modifiedAt {
                if let session = cached.session {
                    sessions.append(session)
                } else {
                    unreadableFiles.append(
                        CodexUnreadableFile(
                            url: url,
                            reason: AppConstants.Codex.missingSessionMetadata
                        ))
                }
                continue
            }

            do {
                let session = try await parseMetadata(url, modifiedAt: modifiedAt)
                cache[url] = CacheEntry(
                    size: size,
                    modifiedAt: modifiedAt,
                    session: session,
                    isComplete: false
                )
                if let session {
                    sessions.append(session)
                } else {
                    unreadableFiles.append(
                        CodexUnreadableFile(
                            url: url,
                            reason: AppConstants.Codex.missingSessionMetadata
                        ))
                }
            } catch {
                unreadableFiles.append(
                    CodexUnreadableFile(
                        url: url,
                        reason: error.localizedDescription
                    ))
            }
        }

        var relevantIDs: Set<String> = [focusedID]
        guard sessions.contains(where: { $0.id == focusedID }) else {
            throw CodexScanError.sessionFileNotFound
        }
        while true {
            let count = relevantIDs.count
            for session in sessions where session.parentID.map(relevantIDs.contains) == true {
                relevantIDs.insert(session.id)
            }
            if relevantIDs.count == count { break }
        }

        var focusedSessions: [CodexSession] = []
        var focusedUnreadableFiles = unreadableFiles.filter {
            $0.url.deletingPathExtension().lastPathComponent.hasSuffix(focusedID)
        }
        for session in sessions where relevantIDs.contains(session.id) {
            try Task.checkCancellation()
            do {
                if let parsedSession = try await scan(file: session.fileURL) {
                    focusedSessions.append(parsedSession)
                } else {
                    focusedUnreadableFiles.append(
                        CodexUnreadableFile(
                            url: session.fileURL,
                            reason: AppConstants.Codex.missingSessionMetadata
                        ))
                }
            } catch {
                focusedUnreadableFiles.append(
                    CodexUnreadableFile(
                        url: session.fileURL,
                        reason: error.localizedDescription
                    ))
            }
        }

        focusedSessions.sort { $0.fileTimestamp > $1.fileTimestamp }
        focusedUnreadableFiles.sort { $0.url.path < $1.url.path }
        return CodexScanResult(
            sessions: focusedSessions,
            unreadableFiles: focusedUnreadableFiles
        )
    }

    func scan(file url: URL) async throws -> CodexSession? {
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ])
        guard values.isRegularFile == true,
            values.isSymbolicLink != true,
            let size = values.fileSize,
            let modifiedAt = values.contentModificationDate
        else {
            throw CodexScanError.cannotReadFileAttributes
        }
        if let cached = cache[url],
            cached.size == size,
            cached.modifiedAt == modifiedAt,
            cached.isComplete
        {
            return cached.session
        }

        let session = try await parse(url, modifiedAt: modifiedAt)
        cache[url] = CacheEntry(
            size: size,
            modifiedAt: modifiedAt,
            session: session,
            isComplete: true
        )
        return session
    }

    private func fileTimestamp(_ url: URL) throws -> String {
        let fileName = url.deletingPathExtension().lastPathComponent
        guard fileName.hasPrefix("rollout-"), fileName.count == 64 else {
            throw CodexScanError.invalidFileName
        }
        let timestamp = String(fileName.dropFirst(8).prefix(19))
        let conversationID = String(fileName.suffix(36))
        guard fileNameDateFormatter.date(from: timestamp) != nil,
            UUID(uuidString: conversationID) != nil
        else {
            throw CodexScanError.invalidFileName
        }
        let displayedTimestamp =
            timestamp.prefix(10)
            + " "
            + timestamp.dropFirst(11).replacingOccurrences(of: "-", with: ":")
        return String(displayedTimestamp)
    }

    private func parseMetadata(_ url: URL, modifiedAt: Date) async throws -> CodexSession? {
        let timestamp = try fileTimestamp(url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        for try await line in handle.bytes.lines where !line.isEmpty {
            try Task.checkCancellation()
            let record = try JSONDecoder().decode(RolloutRecord.self, from: Data(line.utf8))
            guard case .sessionMetadata(let metadata) = record.item else { return nil }
            var builder = SessionBuilder(
                fileURL: url,
                fileTimestamp: timestamp,
                fileModifiedAt: modifiedAt
            )
            builder.metadata = metadata
            builder.status = .unloaded
            builder.updatedAt = max(modifiedAt, record.timestamp)
            return builder.session()
        }
        return nil
    }

    private func parse(_ url: URL, modifiedAt: Date) async throws -> CodexSession? {
        let timestamp = try fileTimestamp(url)

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let length = try handle.seekToEnd()
        var endsWithNewline = true
        if length > 0 {
            try handle.seek(toOffset: length - 1)
            endsWithNewline = try handle.read(upToCount: 1) == Data([0x0A])
        }
        try handle.seek(toOffset: 0)

        var builder = SessionBuilder(
            fileURL: url,
            fileTimestamp: timestamp,
            fileModifiedAt: modifiedAt
        )
        var pendingLine: String?
        for try await line in handle.bytes.lines {
            try Task.checkCancellation()
            if let pendingLine {
                builder.consume(pendingLine)
            }
            pendingLine = line
        }
        if endsWithNewline, let pendingLine {
            builder.consume(pendingLine)
        }
        return builder.session()
    }
}

nonisolated private struct SessionBuilder {
    let decoder = JSONDecoder()
    let fileURL: URL
    let fileTimestamp: String
    var metadata: SessionMetadata?
    var updatedAt: Date
    var model: String?
    var reasoningEffort: String?
    var status: CodexSessionStatus = .running
    var totalUsage = CodexTokenUsage()
    var lastUsage: CodexTokenUsage?
    var contextWindow: Int?
    var completedTurns = 0
    var durationMilliseconds: Int64 = 0
    var timeToFirstTokenMilliseconds: Int64 = 0
    var timeToFirstTokenSamples = 0
    var parseErrors = 0

    init(
        fileURL: URL,
        fileTimestamp: String,
        fileModifiedAt: Date
    ) {
        self.fileURL = fileURL
        self.fileTimestamp = fileTimestamp
        updatedAt = fileModifiedAt
    }

    mutating func consume(_ line: String) {
        guard !line.isEmpty else { return }
        do {
            let record = try decoder.decode(RolloutRecord.self, from: Data(line.utf8))
            updatedAt = max(updatedAt, record.timestamp)
            if let start = metadata?.historyStartOrdinal {
                guard let ordinal = record.ordinal else {
                    parseErrors += 1
                    return
                }
                if ordinal < start { return }
            }
            switch record.item {
                case .sessionMetadata(let value):
                    metadata = value
                case .turnContext(let value):
                    model = value.model
                    reasoningEffort = value.effort
                case .event(let value):
                    consume(value)
                case .ignored:
                    break
            }
        } catch {
            parseErrors += 1
        }
    }

    mutating private func consume(_ event: SessionEvent) {
        switch event {
            case .turnStarted(let window):
                status = .running
                if let window { contextWindow = window }
            case .turnCompleted(let duration, let timeToFirstToken):
                status = .completed
                completedTurns += 1
                if let duration { durationMilliseconds += duration }
                if let timeToFirstToken {
                    timeToFirstTokenMilliseconds += timeToFirstToken
                    timeToFirstTokenSamples += 1
                }
            case .tokenCount(let info):
                guard let info else { return }
                totalUsage = info.total
                lastUsage = info.last
                contextWindow = info.contextWindow
            case .turnAborted(let duration):
                status = .interrupted
                if let duration { durationMilliseconds += duration }
            case .shutdown:
                status = .shutdown
            case .settings(let value):
                model = value.model
                reasoningEffort = value.effort
            case .ignored:
                break
        }
    }

    func session() -> CodexSession? {
        guard let metadata else { return nil }
        return CodexSession(
            id: metadata.id,
            fileURL: fileURL,
            fileTimestamp: fileTimestamp,
            parentID: metadata.parentID,
            updatedAt: updatedAt,
            workingDirectory: metadata.workingDirectory,
            nickname: metadata.nickname,
            role: metadata.role,
            model: model,
            reasoningEffort: reasoningEffort,
            status: status,
            totalUsage: totalUsage,
            lastUsage: lastUsage,
            contextWindow: contextWindow,
            completedTurns: completedTurns,
            durationMilliseconds: durationMilliseconds,
            timeToFirstTokenMilliseconds: timeToFirstTokenMilliseconds,
            timeToFirstTokenSamples: timeToFirstTokenSamples,
            parseErrors: parseErrors
        )
    }
}

nonisolated private struct RolloutRecord: Decodable {
    let timestamp: Date
    let ordinal: UInt64?
    let item: RolloutItem

    enum CodingKeys: String, CodingKey {
        case timestamp
        case ordinal
        case type
        case payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawTimestamp = try container.decode(String.self, forKey: .timestamp)
        guard let parsedTimestamp = Self.parseDate(rawTimestamp) else {
            throw DecodingError.dataCorruptedError(
                forKey: .timestamp,
                in: container,
                debugDescription: "Invalid ISO-8601 timestamp"
            )
        }
        timestamp = parsedTimestamp
        ordinal = try container.decodeIfPresent(UInt64.self, forKey: .ordinal)
        switch try container.decode(String.self, forKey: .type) {
            case "session_meta":
                item = .sessionMetadata(try container.decode(SessionMetadata.self, forKey: .payload))
            case "turn_context":
                item = .turnContext(try container.decode(TurnContext.self, forKey: .payload))
            case "event_msg":
                item = .event(try container.decode(SessionEvent.self, forKey: .payload))
            default:
                item = .ignored
        }
    }

    fileprivate static func parseDate(_ value: String) -> Date? {
        if let date = try? Date(
            value,
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        ) {
            return date
        }
        return try? Date(
            value,
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: false)
        )
    }
}

nonisolated private enum RolloutItem {
    case sessionMetadata(SessionMetadata)
    case turnContext(TurnContext)
    case event(SessionEvent)
    case ignored
}

nonisolated private struct SessionMetadata: Decodable {
    let id: String
    let parentID: String?
    let workingDirectory: String
    let nickname: String?
    let role: String?
    let historyStartOrdinal: UInt64?

    enum CodingKeys: String, CodingKey {
        case id
        case parentID = "parent_thread_id"
        case workingDirectory = "cwd"
        case nickname = "agent_nickname"
        case role = "agent_role"
        case legacyRole = "agent_type"
        case historyStartOrdinal = "subagent_history_start_ordinal"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        role =
            try container.decodeIfPresent(String.self, forKey: .role)
            ?? container.decodeIfPresent(String.self, forKey: .legacyRole)
        historyStartOrdinal = try container.decodeIfPresent(
            UInt64.self,
            forKey: .historyStartOrdinal
        )
    }
}

nonisolated private struct TurnContext: Decodable {
    let model: String
    let effort: String?
}

nonisolated private enum SessionEvent: Decodable {
    case turnStarted(Int?)
    case turnCompleted(Int64?, Int64?)
    case tokenCount(TokenUsageInfo?)
    case turnAborted(Int64?)
    case shutdown
    case settings(SessionSettings)
    case ignored

    enum CodingKeys: String, CodingKey {
        case type
        case modelContextWindow = "model_context_window"
        case duration = "duration_ms"
        case timeToFirstToken = "time_to_first_token_ms"
        case info
        case threadSettings = "thread_settings"
        case model
        case effort = "reasoning_effort"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
            case "task_started", "turn_started":
                self = .turnStarted(try container.decodeIfPresent(Int.self, forKey: .modelContextWindow))
            case "task_complete", "turn_complete":
                self = .turnCompleted(
                    try container.decodeIfPresent(Int64.self, forKey: .duration),
                    try container.decodeIfPresent(Int64.self, forKey: .timeToFirstToken)
                )
            case "token_count":
                self = .tokenCount(try container.decodeIfPresent(TokenUsageInfo.self, forKey: .info))
            case "turn_aborted":
                self = .turnAborted(try container.decodeIfPresent(Int64.self, forKey: .duration))
            case "shutdown_complete":
                self = .shutdown
            case "thread_settings_applied":
                self = .settings(try container.decode(SessionSettings.self, forKey: .threadSettings))
            case "session_configured":
                self = .settings(
                    SessionSettings(
                        model: try container.decode(String.self, forKey: .model),
                        effort: try container.decodeIfPresent(String.self, forKey: .effort)
                    )
                )
            default:
                self = .ignored
        }
    }
}

nonisolated private struct TokenUsageInfo: Decodable {
    let total: CodexTokenUsage
    let last: CodexTokenUsage
    let contextWindow: Int?

    enum CodingKeys: String, CodingKey {
        case total = "total_token_usage"
        case last = "last_token_usage"
        case contextWindow = "model_context_window"
    }
}

nonisolated private struct SessionSettings: Decodable {
    let model: String
    let effort: String?

    enum CodingKeys: String, CodingKey {
        case model
        case effort = "reasoning_effort"
    }
}

nonisolated enum CodexScanError: Error, LocalizedError, Sendable {
    case cannotEnumerate
    case cannotReadFileAttributes
    case invalidFileName
    case sessionFileNotFound

    var errorDescription: String? {
        switch self {
            case .cannotEnumerate: AppConstants.Codex.cannotEnumerate
            case .cannotReadFileAttributes: AppConstants.Codex.missingFileAttributes
            case .invalidFileName: AppConstants.Codex.invalidSessionFileName
            case .sessionFileNotFound: AppConstants.Codex.sessionFileNotFound
        }
    }
}
