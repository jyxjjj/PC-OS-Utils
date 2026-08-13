import Foundation

// 业务层会抛出的错误。
nonisolated enum SubTrackInputField: Equatable, Sendable {
    case name
    case category
    case channel
    case notes
    case currency
    case extensionDays
    case reminderDays
    case officialPrice
    case thirdPartyPrice
}

nonisolated enum SubTrackError: LocalizedError, Sendable {
    case invalidInput(SubTrackInputField, String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case let .invalidInput(_, message): message
        case .unavailable: AppConstants.SubTrack.databaseUnavailable
        }
    }
}

extension Decimal {
    func rounded(scale: Int = AppConstants.SubTrack.Rules.decimalScale) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }

    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}

// 输入校验、到期状态和参考价格规则。
enum SubscriptionRules {
    // 清理用户输入，并检查长度、范围和币种。
    static func validate(_ raw: SubscriptionInput) throws -> SubscriptionInput {
        var input = raw
        input.expiresAt = Calendar.current.startOfDay(for: input.expiresAt)
        input.name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        input.category = input.category.trimmingCharacters(in: .whitespacesAndNewlines)
        input.channel = input.channel.trimmingCharacters(in: .whitespacesAndNewlines)
        input.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !input.name.isEmpty,
              input.name.count <= AppConstants.SubTrack.Rules.maximumNameLength else {
            throw SubTrackError.invalidInput(.name, AppConstants.SubTrack.Rules.invalidName)
        }
        guard !input.category.isEmpty,
              input.category.count <= AppConstants.SubTrack.Rules.maximumCategoryLength else {
            throw SubTrackError.invalidInput(
                .category,
                AppConstants.SubTrack.Rules.invalidCategory
            )
        }
        guard input.channel.count <= AppConstants.SubTrack.Rules.maximumChannelLength else {
            throw SubTrackError.invalidInput(.channel, AppConstants.SubTrack.Rules.invalidChannel)
        }
        guard input.notes.count <= AppConstants.SubTrack.Rules.maximumNotesLength else {
            throw SubTrackError.invalidInput(.notes, AppConstants.SubTrack.Rules.invalidNotes)
        }
        guard AppConstants.SubTrack.currencyCodes.contains(input.currency) else {
            throw SubTrackError.invalidInput(
                .currency,
                AppConstants.SubTrack.Rules.unsupportedCurrency
            )
        }
        guard (AppConstants.SubTrack.Rules.minimumExtensionDays ...
               AppConstants.SubTrack.Rules.maximumExtensionDays).contains(input.extensionDays) else {
            throw SubTrackError.invalidInput(
                .extensionDays,
                AppConstants.SubTrack.Rules.invalidExtensionDays
            )
        }
        guard (AppConstants.SubTrack.Rules.minimumReminderDays ...
               AppConstants.SubTrack.Rules.maximumReminderDays).contains(input.reminderDays) else {
            throw SubTrackError.invalidInput(
                .reminderDays,
                AppConstants.SubTrack.Rules.invalidReminderDays
            )
        }
        try validateMoney(
            input.officialPrice,
            field: .officialPrice,
            label: AppConstants.SubTrack.Rules.officialPrice
        )
        try validateMoney(
            input.thirdPartyReference,
            field: .thirdPartyPrice,
            label: AppConstants.SubTrack.Rules.thirdPartyPrice
        )
        return input
    }

    // 计算剩余天数和当前到期状态。
    static func view(
        for subscription: Subscription,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SubscriptionView {
        let start = calendar.startOfDay(for: now)
        let expiryDay = calendar.startOfDay(for: subscription.expiresAt)
        guard let days = calendar.dateComponents([.day], from: start, to: expiryDay).day else {
            preconditionFailure(AppConstants.SubTrack.Rules.invalidDateCalculation)
        }

        let status: SubscriptionStatus = if expiryDay < start {
            .expired
        } else if days <= subscription.reminderDays {
            .dueSoon
        } else {
            .active
        }
        return SubscriptionView(subscription: subscription, daysRemaining: days, status: status)
    }

    // 预算按官方价和第三方价中的较低值计算。
    static func decisionPrice(for subscription: Subscription) -> Decimal? {
        let official = subscription.officialPrice
        let thirdParty = subscription.thirdPartyReference
        if official > AppConstants.SubTrack.Rules.minimumMoney,
           thirdParty > AppConstants.SubTrack.Rules.minimumMoney {
            return min(official, thirdParty)
        }
        if official > AppConstants.SubTrack.Rules.minimumMoney { return official }
        if thirdParty > AppConstants.SubTrack.Rules.minimumMoney { return thirdParty }
        return nil
    }

    static func decisionPriceKind(for subscription: Subscription) -> String {
        if subscription.officialPrice > AppConstants.SubTrack.Rules.minimumMoney,
           subscription.thirdPartyReference > AppConstants.SubTrack.Rules.minimumMoney {
            return AppConstants.SubTrack.Rules.lowerPriceKind
        }
        if subscription.thirdPartyReference > AppConstants.SubTrack.Rules.minimumMoney {
            return AppConstants.SubTrack.Rules.thirdPartyReferenceKind
        }
        if subscription.officialPrice > AppConstants.SubTrack.Rules.minimumMoney {
            return AppConstants.SubTrack.Rules.officialPriceKind
        }
        return AppConstants.SubTrack.Rules.unsetPriceKind
    }

    private static func validateMoney(
        _ value: Decimal,
        field: SubTrackInputField,
        label: String
    ) throws {
        guard value >= AppConstants.SubTrack.Rules.minimumMoney,
              value <= AppConstants.SubTrack.Rules.maximumMoney else {
            throw SubTrackError.invalidInput(
                field,
                String(format: AppConstants.SubTrack.Rules.invalidMoneyFormat, label)
            )
        }
    }
}

enum SubTrackEngine {
    // 按续费周期推算未来支出，并按币种分别汇总。
    static func forecast(
        subscriptions: [Subscription],
        months: Int = AppConstants.SubTrack.Rules.defaultForecastMonths,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ForecastSummary {
        let monthCount = min(
            max(months, AppConstants.SubTrack.Rules.minimumForecastMonths),
            AppConstants.SubTrack.Rules.maximumForecastMonths
        )
        let today = calendar.startOfDay(for: now)
        let current = calendar.dateComponents([.year, .month], from: today)
        guard let startYear = current.year,
              let startMonth = current.month,
              let start = calendar.date(
                from: DateComponents(
                    year: startYear,
                    month: startMonth,
                    day: AppConstants.SubTrack.Rules.firstDayOfMonth
                )
              ),
              let end = calendar.date(byAdding: .month, value: monthCount, to: start),
              let next90 = calendar.date(
                byAdding: .day,
                value: AppConstants.SubTrack.Rules.forecastDays,
                to: today
              ),
              let next90Exclusive = calendar.date(
                byAdding: .day,
                value: AppConstants.SubTrack.Rules.nextDayOffset,
                to: next90
              ) else {
            return ForecastSummary(buckets: [], next90Days: [])
        }

        let horizon = max(end, next90Exclusive)
        var totalsByMonth: [Int: [String: Decimal]] = [:]
        var next90Totals: [String: Decimal] = [:]

        for item in subscriptions {
            guard let price = SubscriptionRules.decisionPrice(for: item),
                  price > AppConstants.SubTrack.Rules.minimumMoney else {
                continue
            }
            var renewal = max(calendar.startOfDay(for: item.expiresAt), today)
            while renewal < horizon {
                let components = calendar.dateComponents([.year, .month], from: renewal)
                guard let year = components.year, let month = components.month else { break }
                let offset = (year - startYear) * AppConstants.SubTrack.Rules.monthsPerYear
                    + month
                    - startMonth
                if (0 ..< monthCount).contains(offset) {
                    totalsByMonth[offset, default: [:]][item.currency, default: 0] += price
                }
                if renewal <= next90 {
                    next90Totals[item.currency, default: 0] += price
                }
                guard let next = calendar.date(byAdding: .day, value: item.extensionDays, to: renewal) else { break }
                renewal = next
            }
        }

        var buckets: [ForecastBucket] = []
        for offset in 0 ..< monthCount {
            guard let date = calendar.date(byAdding: .month, value: offset, to: start) else { break }
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let year = components.year, let month = components.month else { break }
            buckets.append(ForecastBucket(
                month: monthKey(year: year, month: month),
                totals: currencyTotals(totalsByMonth[offset] ?? [:])
            ))
        }
        return ForecastSummary(buckets: buckets, next90Days: currencyTotals(next90Totals))
    }

    private static func monthKey(year: Int, month: Int) -> String {
        String(format: AppConstants.SubTrack.Rules.monthKeyFormat, year, month)
    }

    private static func currencyTotals(_ values: [String: Decimal]) -> [CurrencyTotal] {
        values
            .map { CurrencyTotal(currency: $0.key, total: $0.value.rounded()) }
            .sorted { $0.currency < $1.currency }
    }
}
