import Foundation

nonisolated struct CodexSessionIndexEntry: Decodable, Identifiable, Sendable {
    let id: String
    let threadName: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadName = "thread_name"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        threadName = try container.decode(String.self, forKey: .threadName)
        let value = try container.decode(String.self, forKey: .updatedAt)
        guard let date = try? Date(
            value,
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .updatedAt,
                in: container,
                debugDescription: "Invalid ISO-8601 timestamp"
            )
        }
        updatedAt = date
    }
}

nonisolated enum CodexSessionStatus: String, Sendable {
    case unloaded
    case running
    case completed
    case interrupted
    case shutdown
}

nonisolated struct CodexThreadSummary: Sendable {
    let status: CodexSessionStatus
    let subagentCount: Int
}

nonisolated struct CodexTokenUsage: Decodable, Equatable, Sendable {
    var inputTokens = 0
    var cachedInputTokens = 0
    var cacheWriteInputTokens = 0
    var outputTokens = 0
    var reasoningOutputTokens = 0
    var totalTokens = 0

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case cacheWriteInputTokens = "cache_write_input_tokens"
        case outputTokens = "output_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
        case totalTokens = "total_tokens"
    }

    init(
        inputTokens: Int = 0,
        cachedInputTokens: Int = 0,
        cacheWriteInputTokens: Int = 0,
        outputTokens: Int = 0,
        reasoningOutputTokens: Int = 0,
        totalTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.cacheWriteInputTokens = cacheWriteInputTokens
        self.outputTokens = outputTokens
        self.reasoningOutputTokens = reasoningOutputTokens
        self.totalTokens = totalTokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        cachedInputTokens = try container.decode(Int.self, forKey: .cachedInputTokens)
        cacheWriteInputTokens = try container.decodeIfPresent(
            Int.self,
            forKey: .cacheWriteInputTokens
        ) ?? 0
        outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        reasoningOutputTokens = try container.decode(Int.self, forKey: .reasoningOutputTokens)
        totalTokens = try container.decode(Int.self, forKey: .totalTokens)
    }

    func adding(_ other: Self) -> Self {
        Self(
            inputTokens: inputTokens + other.inputTokens,
            cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
            cacheWriteInputTokens: cacheWriteInputTokens + other.cacheWriteInputTokens,
            outputTokens: outputTokens + other.outputTokens,
            reasoningOutputTokens: reasoningOutputTokens + other.reasoningOutputTokens,
            totalTokens: totalTokens + other.totalTokens
        )
    }
}

nonisolated struct CodexSession: Identifiable, Sendable {
    let id: String
    let fileURL: URL
    let fileTimestamp: String
    let parentID: String?
    let updatedAt: Date
    let workingDirectory: String
    let nickname: String?
    let role: String?
    let model: String?
    let reasoningEffort: String?
    let status: CodexSessionStatus
    let totalUsage: CodexTokenUsage
    let lastUsage: CodexTokenUsage?
    let contextWindow: Int?
    let completedTurns: Int
    let durationMilliseconds: Int64
    let timeToFirstTokenMilliseconds: Int64
    let timeToFirstTokenSamples: Int
    let parseErrors: Int

    var subagentTitle: String {
        if let nickname, !nickname.isEmpty { return nickname }
        if let role, !role.isEmpty { return role }
        return id
    }
}

nonisolated struct CodexSessionNode: Identifiable, Sendable {
    let session: CodexSession
    let children: [CodexSessionNode]
    let wholeUsage: CodexTokenUsage
    let wholeCompletedTurns: Int
    let wholeDurationMilliseconds: Int64
    let wholeParseErrors: Int
    let wholeTimeToFirstTokenMilliseconds: Int64
    let wholeTimeToFirstTokenSamples: Int

    var id: String { session.id }

    init(session: CodexSession, children: [CodexSessionNode]) {
        self.session = session
        self.children = children
        wholeUsage = children.reduce(session.totalUsage) { $0.adding($1.wholeUsage) }
        wholeCompletedTurns = children.reduce(session.completedTurns) {
            $0 + $1.wholeCompletedTurns
        }
        wholeDurationMilliseconds = children.reduce(session.durationMilliseconds) {
            $0 + $1.wholeDurationMilliseconds
        }
        wholeParseErrors = children.reduce(session.parseErrors) { $0 + $1.wholeParseErrors }
        wholeTimeToFirstTokenMilliseconds = children.reduce(session.timeToFirstTokenMilliseconds) {
            $0 + $1.wholeTimeToFirstTokenMilliseconds
        }
        wholeTimeToFirstTokenSamples = children.reduce(session.timeToFirstTokenSamples) {
            $0 + $1.wholeTimeToFirstTokenSamples
        }
    }

    var averageTimeToFirstTokenMilliseconds: Int64? {
        let samples = wholeTimeToFirstTokenSamples
        guard samples > 0 else { return nil }
        return wholeTimeToFirstTokenMilliseconds / Int64(samples)
    }

}

nonisolated struct CodexScanResult: Sendable {
    let sessions: [CodexSession]
    let unreadableFiles: [CodexUnreadableFile]
}

nonisolated struct CodexUnreadableFile: Identifiable, Sendable {
    let url: URL
    let reason: String

    var id: URL { url }
}
