import SwiftUI

struct TOTPListView: View {
    @Environment(AppState.self) private var appState

    @State private var showAddEntry = false
    @State private var transferMode: TransferMode?
    @State private var entryToEdit: TOTPEntry?
    @State private var entryToDelete: TOTPEntry?
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if appState.entries.isEmpty {
                    emptyState
                } else {
                    TimelineView(
                        .periodic(
                            from: .now,
                            by: AppConstants.Authenticator.List.refreshInterval
                        )
                    ) { context in
                        List {
                            ForEach(appState.entries) { entry in
                                TOTPRowView(entry: entry, date: context.date)
                                .contentShape(Rectangle())
                                .swipeActions(
                                    edge: .trailing,
                                    allowsFullSwipe: false
                                ) {
                                    Button(AppConstants.Common.delete, role: .destructive) {
                                        entryToDelete = entry
                                    }
                                    .tint(.red)

                                    Button(AppConstants.Common.edit) {
                                        entryToEdit = entry
                                    }
                                }
                                .contextMenu {
                                    Button(AppConstants.Common.edit) { entryToEdit = entry }
                                    Divider()
                                    Button(AppConstants.Common.delete, role: .destructive) {
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
            .navigationTitle(AppConstants.Authenticator.List.title)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { appState.lock() } label: {
                        Label(
                            AppConstants.Authenticator.List.lock,
                            systemImage: "lock"
                        )
                    }
                }

                ToolbarSpacer(.fixed)

                ToolbarItemGroup(placement: .automatic) {
                    Button { transferMode = .export } label: {
                        Label(
                            AppConstants.Authenticator.List.export,
                            systemImage: "square.and.arrow.up"
                        )
                    }

                    Button { transferMode = .import } label: {
                        Label(
                            AppConstants.Authenticator.List.import,
                            systemImage: "square.and.arrow.down"
                        )
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button { showAddEntry = true } label: {
                        Label(
                            AppConstants.Authenticator.List.addAccount,
                            systemImage: "plus"
                        )
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
        .sheet(item: $transferMode) { mode in
            ExportImportView(mode: mode)
        }
        .alert(
            AppConstants.Authenticator.List.deleteTitle,
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            presenting: entryToDelete
        ) { entry in
            Button(AppConstants.Common.cancel, role: .cancel) {}
            Button(AppConstants.Common.delete, role: .destructive) {
                entryToDelete = nil
                delete(entry)
            }
        } message: { entry in
            Text(
                String(
                    format: AppConstants.Authenticator.List.deleteMessageFormat,
                    entry.serviceName
                )
            )
        }
        .alert(
            AppConstants.Common.error,
            isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )
        ) {
            Button(AppConstants.Common.confirm) {}
        } message: { Text(errorMessage) }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                AppConstants.Authenticator.List.emptyTitle,
                systemImage: "key.slash"
            )
            .font(AppConstants.Typography.h3.bold())
        } description: {
            Text(AppConstants.Authenticator.List.emptyDescription)
                .font(AppConstants.Typography.p)
        } actions: {
            Button(AppConstants.Authenticator.List.addAccount) { showAddEntry = true }
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
