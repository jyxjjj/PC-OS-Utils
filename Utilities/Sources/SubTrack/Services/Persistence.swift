import Foundation
import SwiftData

@MainActor
final class SubTrackStore {
    let container: ModelContainer

    private var context: ModelContext { container.mainContext }

    init() throws {
        let schema = Schema([
            Subscription.self
        ])
        let configuration = ModelConfiguration(
            AppConstants.SubTrack.modelConfigurationName,
            schema: schema,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        container = try ModelContainer(
            for: schema,
            configurations: configuration
        )
        container.mainContext.autosaveEnabled = false
    }

    func insert(_ subscription: Subscription) throws {
        try transaction {
            context.insert(subscription)
        }
    }

    func update(_ subscription: Subscription, from input: SubscriptionInput) throws {
        try transaction {
            if subscription.name != input.name { subscription.name = input.name }
            if subscription.category != input.category {
                subscription.category = input.category
            }
            if subscription.expiresAt != input.expiresAt {
                subscription.expiresAt = input.expiresAt
            }
            if subscription.extensionDays != input.extensionDays {
                subscription.extensionDays = input.extensionDays
            }
            if subscription.officialPrice != input.officialPrice {
                subscription.officialPrice = input.officialPrice
            }
            if subscription.thirdPartyReference != input.thirdPartyReference {
                subscription.thirdPartyReference = input.thirdPartyReference
            }
            if subscription.channel != input.channel {
                subscription.channel = input.channel
            }
            if subscription.priority != input.priority {
                subscription.priority = input.priority
            }
            if subscription.notes != input.notes { subscription.notes = input.notes }
            if subscription.currency != input.currency {
                subscription.currency = input.currency
            }
            if subscription.reminderDays != input.reminderDays {
                subscription.reminderDays = input.reminderDays
            }
        }
    }

    func delete(_ subscription: Subscription) throws {
        try transaction {
            context.delete(subscription)
        }
    }

    private func transaction(_ changes: () throws -> Void) throws {
        do {
            try changes()
            guard context.hasChanges else { return }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
