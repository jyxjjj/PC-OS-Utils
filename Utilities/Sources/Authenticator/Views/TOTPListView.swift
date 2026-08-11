import SwiftUI

struct TOTPListView: View {
    @Environment(AppState.self) private var appState

    @State private var showAddEntry = false
    @State private var showExportImport = false
    @State private var entryToEdit: TOTPEntry?
    @State private var entryToDelete: TOTPEntry?
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if appState.entries.isEmpty {
                    emptyState
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        List {
                            ForEach(appState.entries) { entry in
                                TOTPRowView(entry: entry, date: context.date)
                                .contentShape(Rectangle())
                                .swipeActions(
                                    edge: .trailing,
                                    allowsFullSwipe: false
                                ) {
                                    Button("删除", role: .destructive) {
                                        entryToDelete = entry
                                    }
                                    .tint(.red)

                                    Button("编辑") {
                                        entryToEdit = entry
                                    }
                                    .tint(.green)
                                }
                                .contextMenu {
                                    Button("编辑") { entryToEdit = entry }
                                    Divider()
                                    Button("删除", role: .destructive) {
                                        entryToDelete = entry
                                    }
                                }
                            }
                            .onMove(perform: moveEntries)
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("身份验证器")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { appState.lock() } label: {
                        Label("锁定", systemImage: "lock")
                    }

                    Button { showExportImport = true } label: {
                        Label(
                            "导出 / 导入",
                            systemImage: "square.and.arrow.up.on.square"
                        )
                    }

                    Button { showAddEntry = true } label: {
                        Label("添加账户", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            EntryEditorView()
        }
        .sheet(item: $entryToEdit) { entry in
            EntryEditorView(entry: entry)
        }
        .sheet(isPresented: $showExportImport) {
            ExportImportView()
        }
        .alert(
            "删除账户？",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            presenting: entryToDelete
        ) { entry in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                entryToDelete = nil
                delete(entry)
            }
        } message: { entry in
            Text(
                "将永久删除 \"\(entry.serviceName)\" 的验证码账户。"
                    + "此操作无法撤销。"
            )
        }
        .alert(
            "错误",
            isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )
        ) {
            Button("确定") {}
        } message: { Text(errorMessage) }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无账户", systemImage: "key.slash")
        } description: {
            Text("添加账户以生成验证码。")
        } actions: {
            Button("添加账户") { showAddEntry = true }
        }
    }

    private func delete(_ entry: TOTPEntry) {
        do {
            try appState.deleteEntry(id: entry.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveEntries(from source: IndexSet, to destination: Int) {
        var orderedIDs = appState.entries.map(\.id)
        orderedIDs.move(fromOffsets: source, toOffset: destination)
        do {
            try appState.reorderEntries(ids: orderedIDs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
