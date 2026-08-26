import Foundation
import Observation
import SwiftData

enum PresentedSheet: Identifiable {
    enum ID: Hashable {
        case editor(PersistentIdentifier?)
    }

    case editor(Subscription?)

    var id: ID {
        switch self {
            case .editor(let subscription): .editor(subscription?.persistentModelID)
        }
    }
}

@MainActor
@Observable
final class AppModel {
    private(set) var initializationError: String?
    private(set) var clock = Calendar.current.startOfDay(for: Date())
    var query = ""
    var priorityFilter: SubscriptionPriority?
    var notice = ""
    var presentedSheet: PresentedSheet?

    private var store: SubTrackStore?

    var container: ModelContainer? { store?.container }

    init() {
        initializeStore()
    }

    func initializeStore() {
        do {
            let store = try SubTrackStore()
            self.store = store
            initializationError = nil
            clock = Calendar.current.startOfDay(for: Date())
        } catch {
            store = nil
            initializationError = error.localizedDescription
        }
    }

    func filteredViews(from views: [SubscriptionView]) -> [SubscriptionView] {
        let keyword =
            query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedLowercase
        return
            views
            .filter { view in
                let item = view.subscription
                if let priorityFilter, priorityFilter != item.priority { return false }
                if keyword.isEmpty { return true }
                let searchable = [
                    item.name,
                    item.category,
                    item.channel,
                    item.notes,
                ].joined(separator: " ").localizedLowercase
                return searchable.contains(keyword)
            }
    }

    func saveSubscription(
        _ rawInput: SubscriptionInput,
        subscription: Subscription?
    ) throws {
        let input = try SubscriptionRules.validate(rawInput)
        guard let store else { throw SubTrackError.unavailable }
        if let subscription {
            try store.update(subscription, from: input)
            notice = AppConstants.SubTrack.State.updatedNotice
        } else {
            try store.insert(Subscription(input: input))
            notice = AppConstants.SubTrack.State.createdNotice
        }
    }

    func remove(_ subscription: Subscription) throws {
        guard let store else { throw SubTrackError.unavailable }
        try store.delete(subscription)
        notice = AppConstants.SubTrack.State.deletedNotice
    }

    func runDayChangeRefreshLoop() async {
        for await _ in NotificationCenter.default.messages(
            of: Calendar.self,
            for: .calendarDayChanged
        ) {
            refreshForForeground()
        }
    }

    func refreshForForeground() {
        guard store != nil else { return }
        let currentDay = Calendar.current.startOfDay(for: Date())
        guard clock != currentDay else { return }
        clock = currentDay
    }
}
