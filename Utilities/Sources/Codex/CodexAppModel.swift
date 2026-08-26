import Darwin
import Foundation
import Observation

@MainActor
@Observable
final class CodexAppModel {
    private let scanner = CodexSessionScanner()
    private let expectedDirectory: URL = {
        guard let account = getpwuid(getuid()) else {
            preconditionFailure("无法解析当前用户目录")
        }
        return URL(fileURLWithPath: String(cString: account.pointee.pw_dir), isDirectory: true)
            .appendingPathComponent(AppConstants.Codex.directoryName, isDirectory: true)
            .standardizedFileURL
    }()

    private(set) var directoryURL: URL?
    private(set) var indexEntries: [CodexSessionIndexEntry] = []
    private var sessions: [CodexSession] = []
    private(set) var selectedNode: CodexSessionNode?
    private(set) var focusedDescendants: [CodexSessionNode] = []
    private(set) var threadSummaries: [String: CodexThreadSummary] = [:]
    private(set) var unreadableFiles: [CodexUnreadableFile] = []
    private(set) var isRefreshing = false
    private(set) var errorMessage: String?
    private var refreshGeneration = 0
    var selectedID: String? {
        didSet {
            guard selectedID != oldValue else { return }
            sessions = []
            selectedNode = nil
            focusedDescendants = []
            unreadableFiles = []
        }
    }

    var selectedEntry: CodexSessionIndexEntry? {
        guard let selectedID else { return nil }
        return indexEntries.first { $0.id == selectedID }
    }

    func summary(for id: String) -> CodexThreadSummary? {
        threadSummaries[id]
    }

    init() {
        restoreDirectory()
    }

    func selectDirectory(_ url: URL) async {
        do {
            guard url.standardizedFileURL.path == expectedDirectory.path else {
                throw CodexDirectoryError.invalidDirectory(
                    expected: expectedDirectory.path,
                    selected: url.path
                )
            }
            guard url.startAccessingSecurityScopedResource() else {
                throw CodexDirectoryError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var stale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            UserDefaults.standard.set(data, forKey: AppConstants.Codex.bookmarkKey)
            directoryURL = resolvedURL
            errorMessage = nil
            await refresh()
        } catch {
            if Task.isCancelled { return }
            errorMessage = error.localizedDescription
        }
    }

    func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func refresh() async {
        await refresh(focusedID: nil)
    }

    func refreshVisibleContent() async {
        await refresh(focusedID: selectedID)
    }

    func runFocusedRefreshLoop() async {
        guard selectedID != nil else { return }
        await refresh(focusedID: selectedID)
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(AppConstants.Codex.refreshInterval))
            } catch {
                return
            }
            await refresh(focusedID: selectedID)
        }
    }

    private func refresh(focusedID: String?) async {
        guard let directoryURL else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        isRefreshing = true
        guard directoryURL.startAccessingSecurityScopedResource() else {
            errorMessage = AppConstants.Codex.accessDenied
            isRefreshing = false
            return
        }
        defer {
            directoryURL.stopAccessingSecurityScopedResource()
            if refreshGeneration == generation {
                isRefreshing = false
            }
        }

        do {
            let entries = try await scanner.loadIndex(directoryURL)
            let result: CodexScanResult?
            if let focusedID, entries.contains(where: { $0.id == focusedID }) {
                result = try await scanner.scanThread(directoryURL, focusedID: focusedID)
            } else {
                result = nil
            }

            guard refreshGeneration == generation, self.directoryURL == directoryURL else { return }
            indexEntries = entries
            if let selectedID, !entries.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
                sessions = []
                selectedNode = nil
                focusedDescendants = []
                unreadableFiles = []
            } else if let focusedID, self.selectedID == focusedID, let result {
                sessions = result.sessions
                unreadableFiles = result.unreadableFiles
                rebuildSessionTree()
            }
            errorMessage = nil
        } catch {
            guard !Task.isCancelled, refreshGeneration == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func restoreDirectory() {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.Codex.bookmarkKey) else {
            return
        }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            guard url.standardizedFileURL.path == expectedDirectory.path else {
                throw CodexDirectoryError.invalidDirectory(
                    expected: expectedDirectory.path,
                    selected: url.path
                )
            }
            directoryURL = url
            if stale {
                guard url.startAccessingSecurityScopedResource() else {
                    throw CodexDirectoryError.accessDenied
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let replacement = try url.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(replacement, forKey: AppConstants.Codex.bookmarkKey)
            }
        } catch {
            directoryURL = nil
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildSessionTree() {
        guard let selectedID else {
            selectedNode = nil
            focusedDescendants = []
            return
        }
        var sessionsByID: [String: CodexSession] = [:]
        for session in sessions where sessionsByID[session.id] == nil {
            sessionsByID[session.id] = session
        }
        let uniqueSessions = Array(sessionsByID.values)
        let children = Dictionary(
            grouping: uniqueSessions.compactMap { session in
                session.parentID.map { ($0, session) }
            }, by: { $0.0 }
        ).mapValues { $0.map { $0.1 } }

        func node(_ session: CodexSession) -> CodexSessionNode {
            CodexSessionNode(
                session: session,
                children: (children[session.id] ?? []).map(node).sorted {
                    $0.session.fileTimestamp > $1.session.fileTimestamp
                }
            )
        }

        selectedNode = uniqueSessions.first { $0.id == selectedID }.map(node)
        if let selectedNode {
            var descendants: [CodexSessionNode] = []
            func appendDescendants(_ node: CodexSessionNode) {
                for child in node.children {
                    descendants.append(child)
                    appendDescendants(child)
                }
            }
            appendDescendants(selectedNode)
            focusedDescendants = descendants
            threadSummaries[selectedID] = CodexThreadSummary(
                status: selectedNode.session.status,
                subagentCount: descendants.count
            )
        } else {
            focusedDescendants = []
        }
    }
}

nonisolated private enum CodexDirectoryError: Error, LocalizedError {
    case accessDenied
    case invalidDirectory(expected: String, selected: String)

    var errorDescription: String? {
        switch self {
            case .accessDenied: AppConstants.Codex.accessDenied
            case .invalidDirectory(let expected, let selected):
                String(format: AppConstants.Codex.invalidDirectory, expected, selected)
        }
    }
}
