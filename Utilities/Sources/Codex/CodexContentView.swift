import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CodexContentView: View {
    @Environment(CodexAppModel.self) private var model
    @State private var isChoosingDirectory = false

    var body: some View {
        @Bindable var model = model

        Group {
            if model.directoryURL == nil {
                if let error = model.errorMessage {
                    unavailable(
                        title: AppConstants.Codex.directorySelectionFailed,
                        description: error,
                        symbol: "exclamationmark.triangle",
                        isError: true
                    )
                } else {
                    unavailable(
                        title: AppConstants.Codex.authorizationTitle,
                        description: AppConstants.Codex.authorizationDescription,
                        symbol: "folder.badge.questionmark",
                        isError: false
                    )
                }
            } else if model.isRefreshing, model.indexEntries.isEmpty {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage, model.indexEntries.isEmpty {
                unavailable(
                    title: AppConstants.Codex.loadFailed,
                    description: error,
                    symbol: "exclamationmark.triangle",
                    isError: true
                )
            } else if model.indexEntries.isEmpty, !model.isRefreshing {
                unavailable(
                    title: AppConstants.Codex.noSessions,
                    description: AppConstants.Codex.noSessionsDescription,
                    symbol: "text.page.slash",
                    isError: false
                )
            } else {
                NavigationSplitView {
                    List(selection: $model.selectedID) {
                        Section {
                            ForEach(model.indexEntries) { entry in
                                let summary = model.summary(for: entry.id)
                                SessionRow(
                                    entry: entry,
                                    status: summary?.status ?? .unloaded,
                                    subagentCount: summary?.subagentCount ?? 0
                                )
                                .tag(entry.id)
                            }
                        } header: {
                            Text(AppConstants.Codex.mainTasks)
                                .font(AppConstants.Typography.h5.bold())
                        }
                    }
                    .navigationSplitViewColumnWidth(
                        min: AppConstants.Codex.sidebarMinimumWidth,
                        ideal: AppConstants.Codex.sidebarIdealWidth
                    )
                } detail: {
                    VStack(spacing: 0) {
                        if !model.unreadableFiles.isEmpty || model.errorMessage != nil {
                            VStack(alignment: .leading, spacing: 6) {
                                if let error = model.errorMessage {
                                    Label(error, systemImage: "exclamationmark.triangle")
                                        .foregroundStyle(.red)
                                }
                                if !model.unreadableFiles.isEmpty {
                                    Label(
                                        String(
                                            format: AppConstants.Codex.unreadableFiles,
                                            model.unreadableFiles.count
                                        ),
                                        systemImage: "exclamationmark.triangle"
                                    )
                                    .foregroundStyle(.orange)

                                    ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 4) {
                                            ForEach(model.unreadableFiles) { file in
                                                Button {
                                                    NSWorkspace.shared.activateFileViewerSelecting([
                                                        file.url,
                                                    ])
                                                } label: {
                                                    HStack {
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(file.url.lastPathComponent)
                                                                .lineLimit(1)
                                                            Text(file.reason)
                                                                .font(AppConstants.Typography.span)
                                                                .foregroundStyle(.secondary)
                                                                .lineLimit(2)
                                                        }
                                                        Spacer()
                                                        Image(systemName: "arrow.forward.circle")
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                                .help(file.url.path(percentEncoded: false))
                                            }
                                        }
                                    }
                                    .frame(
                                        maxHeight: AppConstants.Codex
                                            .unreadableFilesMaximumHeight
                                    )
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary)

                            Divider()
                        }

                        if let node = model.selectedNode, let entry = model.selectedEntry {
                            SessionDetail(
                                node: node,
                                descendants: model.focusedDescendants,
                                title: entry.threadName
                            )
                        } else if model.selectedID != nil, model.isRefreshing {
                            ProgressView()
                                .controlSize(.large)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ContentUnavailableView {
                                Label(
                                    AppConstants.Codex.selectSession,
                                    systemImage: "sidebar.left"
                                )
                                .font(AppConstants.Typography.h3.bold())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(AppConstants.Application.codexName)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await model.refreshVisibleContent() }
                } label: {
                    Label(AppConstants.Codex.refresh, systemImage: "arrow.clockwise")
                }
                .disabled(model.directoryURL == nil || model.isRefreshing)

            }
        }
        .fileImporter(
            isPresented: $isChoosingDirectory,
            allowedContentTypes: [.folder]
        ) { result in
            do {
                let url = try result.get()
                Task { await model.selectDirectory(url) }
            } catch {
                model.report(error)
            }
        }
        .fileDialogBrowserOptions(.includeHiddenFiles)
        .task {
            await model.refresh()
        }
        .task(id: model.selectedID) {
            await model.runFocusedRefreshLoop()
        }
    }

    private func unavailable(
        title: String,
        description: String,
        symbol: String,
        isError: Bool
    ) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
                .font(AppConstants.Typography.h3.bold())
                .foregroundStyle(isError ? Color.red : Color.primary)
        } description: {
            Text(description)
                .font(AppConstants.Typography.p)
        } actions: {
            Button(AppConstants.Codex.chooseDirectory) {
                isChoosingDirectory = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SessionRow: View {
    let entry: CodexSessionIndexEntry
    let status: CodexSessionStatus
    let subagentCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(AppConstants.Typography.p.weight(.semibold))
                    .lineLimit(1)
                Text(entry.id)
                    .font(AppConstants.Typography.span)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(entry.updatedAt.formatted(Date.ISO8601FormatStyle(timeZone: .current)))
                    .font(AppConstants.Typography.span)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var displayName: String {
        guard subagentCount > 0 else { return entry.threadName }
        return "\(entry.threadName)(\(subagentCount))"
    }

    private var statusSymbol: String {
        switch status {
        case .unloaded: "circle.fill"
        case .running: "circle.fill"
        case .completed: "checkmark.circle.fill"
        case .interrupted: "pause.circle.fill"
        case .shutdown: "stop.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .unloaded: .secondary
        case .running: .green
        case .completed: .blue
        case .interrupted: .orange
        case .shutdown: .secondary
        }
    }
}

private struct TokenSegment: Identifiable {
    let title: String
    let value: Int
    let color: Color

    var id: String { title }

    init(_ title: String, _ value: Int, _ color: Color) {
        self.title = title
        self.value = value
        self.color = color
    }
}

private struct SessionDetail: View {
    let node: CodexSessionNode
    let descendants: [CodexSessionNode]
    let title: String
    @State private var expandedSubagentIDs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(AppConstants.Typography.h2.bold())
                        .textSelection(.enabled)
                    Text(metadata)
                        .font(AppConstants.Typography.span)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                contextSection
                tokenSection(AppConstants.Codex.wholeSession, usage: node.wholeUsage)
                if let lastUsage = node.session.lastUsage {
                    tokenSection(AppConstants.Codex.lastTurn, usage: lastUsage)
                }

                GroupBox {
                    VStack(spacing: 10) {
                        detail(AppConstants.Codex.status, statusName)
                        detail(
                            AppConstants.Codex.completedTurns,
                            node.wholeCompletedTurns.formatted(.number.grouping(.never))
                        )
                        detail(AppConstants.Codex.duration, duration(node.wholeDurationMilliseconds))
                        detail(
                            AppConstants.Codex.averageTTFT,
                            node.averageTimeToFirstTokenMilliseconds.map(duration)
                                ?? AppConstants.Common.emDash
                        )
                        detail(AppConstants.Codex.lastActivity, timestamp(node.session.updatedAt))
                        detail(
                            AppConstants.Codex.parseErrors,
                            node.wholeParseErrors.formatted(.number.grouping(.never))
                        )
                    }
                    .padding(.vertical, 4)
                } label: {
                    Text(AppConstants.Codex.sessionDetails)
                        .font(AppConstants.Typography.h4.bold())
                }

                if !descendants.isEmpty {
                    subagentSection
                }
            }
            .padding(24)
            .frame(
                maxWidth: AppConstants.Codex.detailMaximumWidth,
                alignment: .leading
            )
            .frame(maxWidth: .infinity)
        }
    }

    private var contextSection: some View {
        GroupBox {
            if let usage = node.session.lastUsage, let window = node.session.contextWindow, window > 0 {
                let ratio = Double(usage.totalTokens) / Double(window)
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: min(ratio, 1))
                        .tint(contextColor(ratio))
                    HStack {
                        Text(String(
                            format: AppConstants.Codex.contextUsed,
                            tokenCount(usage.totalTokens)
                        ))
                        Spacer()
                        Text(ratio.formatted(.percent.precision(.fractionLength(1))))
                    }
                    .font(AppConstants.Typography.p)
                    .foregroundStyle(.secondary)
                    Text(
                        String(
                            format: AppConstants.Codex.contextRemaining,
                            tokenCount(max(window - usage.totalTokens, 0)),
                            tokenCount(window)
                        )
                    )
                    .font(AppConstants.Typography.span)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                Text(AppConstants.Codex.notAvailable)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        } label: {
            Text(AppConstants.Codex.currentContext)
                .font(AppConstants.Typography.h4.bold())
        }
    }

    private var subagentSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(descendants) { child in
                    DisclosureGroup(isExpanded: subagentExpansionBinding(child.id)) {
                        VStack(spacing: 8) {
                            detail(AppConstants.Codex.status, statusName(child.session.status))
                            if let model = child.session.model {
                                detail(AppConstants.Codex.model, model)
                            }
                            if let reasoningEffort = child.session.reasoningEffort {
                                detail(AppConstants.Codex.reasoningEffort, reasoningEffort)
                            }
                            if let role = child.session.role {
                                detail(AppConstants.Codex.role, role)
                            }
                            detail(
                                AppConstants.Codex.workingDirectory,
                                child.session.workingDirectory
                            )
                            detail(
                                AppConstants.Codex.completedTurns,
                                child.wholeCompletedTurns.formatted(.number.grouping(.never))
                            )
                            detail(
                                AppConstants.Codex.duration,
                                duration(child.wholeDurationMilliseconds)
                            )
                            detail(
                                AppConstants.Codex.lastActivity,
                                timestamp(child.session.updatedAt)
                            )
                            detail(
                                AppConstants.Codex.parseErrors,
                                child.wholeParseErrors.formatted(.number.grouping(.never))
                            )
                            tokenSection(
                                AppConstants.Codex.tokenComposition,
                                usage: child.wholeUsage
                            )
                        }
                        .padding(.top, 8)
                        .padding(.leading, 18)
                        .textSelection(.enabled)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(statusColor(child.session.status))
                                .frame(
                                    width: AppConstants.Codex.statusIndicatorSize,
                                    height: AppConstants.Codex.statusIndicatorSize
                                )
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(child.session.subagentTitle)
                                    .font(AppConstants.Typography.h5.weight(.semibold))
                                Text(child.session.id)
                                    .font(AppConstants.Typography.span.monospaced())
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text(child.session.fileTimestamp)
                                    Spacer()
                                    Text(statusName(child.session.status))
                                }
                                .font(AppConstants.Typography.span)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Text(AppConstants.Codex.subagents)
                .font(AppConstants.Typography.h4.bold())
        }
    }

    private func subagentExpansionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedSubagentIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedSubagentIDs.insert(id)
                } else {
                    expandedSubagentIDs.remove(id)
                }
            }
        )
    }

    private func tokenSection(_ title: String, usage: CodexTokenUsage) -> some View {
        let uncachedInput = usage.inputTokens
            - usage.cachedInputTokens
            - usage.cacheWriteInputTokens
        let regularOutput = usage.outputTokens - usage.reasoningOutputTokens
        precondition(
            uncachedInput >= 0
                && regularOutput >= 0
                && usage.inputTokens + usage.outputTokens == usage.totalTokens
        )

        return GroupBox {
            VStack(spacing: 18) {
                tokenComposition(
                    AppConstants.Codex.totalComposition,
                    total: usage.totalTokens,
                    segments: [
                        TokenSegment(AppConstants.Codex.input, usage.inputTokens, .blue),
                        TokenSegment(AppConstants.Codex.output, usage.outputTokens, .orange),
                    ]
                )
                tokenComposition(
                    AppConstants.Codex.inputComposition,
                    total: usage.inputTokens,
                    segments: [
                        TokenSegment(AppConstants.Codex.cachedInput, usage.cachedInputTokens, .cyan),
                        TokenSegment(AppConstants.Codex.cacheWrite, usage.cacheWriteInputTokens, .indigo),
                        TokenSegment(AppConstants.Codex.uncachedInput, uncachedInput, .blue),
                    ]
                )
                tokenComposition(
                    AppConstants.Codex.outputComposition,
                    total: usage.outputTokens,
                    segments: [
                        TokenSegment(AppConstants.Codex.reasoning, usage.reasoningOutputTokens, .red),
                        TokenSegment(AppConstants.Codex.regularOutput, regularOutput, .orange),
                    ]
                )
            }
            .padding(.vertical, 4)
        } label: {
            Text(title)
                .font(AppConstants.Typography.h4.bold())
        }
    }

    private func tokenComposition(
        _ title: String,
        total: Int,
        segments: [TokenSegment]
    ) -> some View {
        let visibleSegments = segments.filter { $0.value > 0 }

        return VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(AppConstants.Typography.p.weight(.semibold))
                Spacer()
                Text(tokenCount(total) + " Tokens")
                    .font(AppConstants.Typography.p.monospacedDigit())
            }
            GeometryReader { proxy in
                let spacing = CGFloat(max(visibleSegments.count - 1, 0)) * 2
                let availableWidth = max(proxy.size.width - spacing, 0)
                HStack(spacing: 2) {
                    ForEach(visibleSegments) { segment in
                        segment.color
                            .frame(
                                width: total == 0
                                    ? 0
                                    : availableWidth * CGFloat(segment.value) / CGFloat(total)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary)
                .clipShape(.capsule)
            }
            .frame(height: 8)
            ForEach(segments) { segment in
                HStack(spacing: 8) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 8, height: 8)
                    Text(segment.title)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(tokenCount(segment.value) + " Tokens")
                        .font(AppConstants.Typography.p.monospacedDigit())
                    Text(
                        (total == 0 ? 0 : Double(segment.value) / Double(total))
                            .formatted(.percent.precision(.fractionLength(1)))
                    )
                    .font(AppConstants.Typography.span.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
            .textSelection(.enabled)
    }

    private var metadata: String {
        [
            node.session.model,
            node.session.reasoningEffort,
            node.session.role,
            node.session.workingDirectory,
        ]
        .compactMap { $0 }
        .joined(separator: AppConstants.Common.itemSeparator)
    }

    private var statusName: String {
        statusName(node.session.status)
    }

    private func statusName(_ status: CodexSessionStatus) -> String {
        switch status {
        case .unloaded: AppConstants.Codex.unloaded
        case .running: AppConstants.Codex.running
        case .completed: AppConstants.Codex.completed
        case .interrupted: AppConstants.Codex.interrupted
        case .shutdown: AppConstants.Codex.shutdown
        }
    }

    private func statusColor(_ status: CodexSessionStatus) -> Color {
        switch status {
        case .unloaded, .shutdown: .secondary
        case .running: .green
        case .completed: .blue
        case .interrupted: .orange
        }
    }

    private func contextColor(_ ratio: Double) -> Color {
        if ratio >= AppConstants.Codex.dangerThreshold { return .red }
        if ratio >= AppConstants.Codex.warningThreshold { return .orange }
        return .blue
    }

    private func tokenCount(_ value: Int) -> String {
        precondition(value >= 0)
        let millions = value / 1_000_000
        let thousands = value % 1_000_000 / 1_000
        let remainder = value % 1_000
        var parts: [String] = []
        if millions > 0 { parts.append("\(millions)M") }
        if thousands > 0 { parts.append("\(thousands)K") }
        if remainder > 0 || parts.isEmpty { parts.append("\(remainder)") }
        return parts.joined(separator: " ")
    }

    private func timestamp(_ date: Date) -> String {
        date.formatted(
            Date.ISO8601FormatStyle(timeZone: .current)
                .year()
                .month()
                .day()
                .dateSeparator(.dash)
                .time(includingFractionalSeconds: false)
                .timeSeparator(.colon)
                .dateTimeSeparator(.space)
        )
    }

    private func duration(_ milliseconds: Int64) -> String {
        let seconds = Double(milliseconds) / 1_000
        if seconds < 60 {
            return seconds.formatted(
                .number.grouping(.never).precision(.fractionLength(1))
            ) + " s"
        }
        return (seconds / 60).formatted(
            .number.grouping(.never).precision(.fractionLength(1))
        ) + " min"
    }
}
