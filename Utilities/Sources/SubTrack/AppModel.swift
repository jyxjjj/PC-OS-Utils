import Foundation
import Observation
import SwiftData

enum PresentedSheet: Identifiable {
    enum ID: Hashable {
        case editor(PersistentIdentifier?)
        case purchase(PersistentIdentifier)
    }

    case editor(Subscription?)
    case purchase(Subscription)

    var id: ID {
        switch self {
        case let .editor(subscription): .editor(subscription?.persistentModelID)
        case let .purchase(subscription): .purchase(subscription.persistentModelID)
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

    var canCreateProject: Bool {
        store != nil && presentedSheet == nil
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
        let keyword = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedLowercase
        return views
            .filter { view in
                let item = view.subscription
                if let priorityFilter, priorityFilter != item.priority { return false }
                if keyword.isEmpty { return true }
                let searchable = "\(item.name) \(item.category) \(item.channel) \(item.notes)"
                    .localizedLowercase
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
            notice = "项目已更新"
        } else {
            try store.insert(Subscription(input: input))
            notice = "项目已创建"
        }
    }

    func remove(_ subscription: Subscription) throws {
        guard let store else { throw SubTrackError.unavailable }
        try store.delete(subscription)
        notice = "项目已删除"
    }

    func recordPurchase(
        subscription: Subscription,
        purchasedAt: Date,
        price: Decimal,
        extensionDays: Int,
        channel: String,
        notes: String
    ) throws {
        guard let store else { throw SubTrackError.unavailable }
        let purchase = try SubTrackEngine.recordPurchase(
            for: subscription,
            purchasedAt: purchasedAt,
            price: price,
            extensionDays: extensionDays,
            channel: channel,
            notes: notes
        )
        try store.recordPurchase(for: subscription, purchase: purchase)
        notice = "续费已记录"
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
