import Foundation
import SwiftData

nonisolated enum SubscriptionPriority: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case essential
    case high
    case normal
    case low

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .essential: "刚需"
        case .high: "高频"
        case .normal: "普通"
        case .low: "低频"
        }
    }
}

nonisolated enum SubscriptionStatus: Sendable {
    case active
    case dueSoon
    case expired

    var localizedName: String {
        switch self {
        case .active: "有效"
        case .dueSoon: "即将到期"
        case .expired: "已到期"
        }
    }
}

nonisolated struct SubscriptionInput: Sendable {
    var name: String = ""
    var category: String = ""
    var expiresAt: Date = Date()
    var extensionDays: Int = 0
    var officialPrice: Decimal = 0
    var thirdPartyReference: Decimal = 0
    var channel: String = ""
    var priority: SubscriptionPriority = .normal
    var notes: String = ""
    var currency: String = "CNY"
    var reminderDays: Int = 30
}

@Model
final class Subscription {
    var name: String
    var category: String
    var expiresAt: Date
    var extensionDays: Int
    var officialPrice: Decimal
    var thirdPartyReference: Decimal
    var channel: String
    var priority: SubscriptionPriority
    var notes: String
    var currency: String
    var reminderDays: Int

    @Relationship(deleteRule: .cascade, inverse: \PurchaseRecord.subscription)
    var purchases: [PurchaseRecord] = []

    init(input: SubscriptionInput) {
        name = input.name
        category = input.category
        expiresAt = input.expiresAt
        extensionDays = input.extensionDays
        officialPrice = input.officialPrice
        thirdPartyReference = input.thirdPartyReference
        channel = input.channel
        priority = input.priority
        notes = input.notes
        currency = input.currency
        reminderDays = input.reminderDays
    }

    var input: SubscriptionInput {
        SubscriptionInput(
            name: name,
            category: category,
            expiresAt: expiresAt,
            extensionDays: extensionDays,
            officialPrice: officialPrice,
            thirdPartyReference: thirdPartyReference,
            channel: channel,
            priority: priority,
            notes: notes,
            currency: currency,
            reminderDays: reminderDays
        )
    }
}

@Model
final class PurchaseRecord {
    var purchasedAt: Date
    var price: Decimal
    var currency: String
    var channel: String
    var extensionDays: Int
    var newExpiry: Date
    var notes: String
    var subscription: Subscription?

    init(
        purchasedAt: Date,
        price: Decimal,
        currency: String,
        channel: String,
        extensionDays: Int,
        newExpiry: Date,
        notes: String
    ) {
        self.purchasedAt = purchasedAt
        self.price = price
        self.currency = currency
        self.channel = channel
        self.extensionDays = extensionDays
        self.newExpiry = newExpiry
        self.notes = notes
    }
}

struct SubscriptionView: Identifiable {
    var subscription: Subscription
    var daysRemaining: Int
    var status: SubscriptionStatus
    var id: PersistentIdentifier { subscription.persistentModelID }
}

nonisolated struct CurrencyTotal: Identifiable, Sendable {
    var currency: String
    var total: Decimal
    var id: String { currency }
}

nonisolated struct ForecastBucket: Identifiable, Sendable {
    var month: String
    var totals: [CurrencyTotal]
    var id: String { month }
}

nonisolated struct ForecastSummary: Sendable {
    var buckets: [ForecastBucket]
    var next90Days: [CurrencyTotal]
}
