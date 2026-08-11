import Foundation

// 业务层会抛出的错误。
enum SubTrackError: LocalizedError, Sendable {
    case invalidInput(String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case let .invalidInput(message): message
        case .unavailable: "SubTrack 数据库不可用"
        }
    }
}

extension Decimal {
    func rounded(scale: Int = 2) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }

    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}

// 输入校验、到期状态和参考价格规则。
enum SubscriptionRules {
    static let allowedCurrencies = ["CNY", "EUR", "SGD", "TWD", "HKD", "USD", "JPY"]

    // 清理用户输入，并检查长度、范围和币种。
    static func validate(_ raw: SubscriptionInput) throws -> SubscriptionInput {
        var input = raw
        input.expiresAt = Calendar.current.startOfDay(for: input.expiresAt)
        input.name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        input.category = input.category.trimmingCharacters(in: .whitespacesAndNewlines)
        input.channel = input.channel.trimmingCharacters(in: .whitespacesAndNewlines)
        input.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !input.name.isEmpty, input.name.count <= 120 else {
            throw SubTrackError.invalidInput("名称不能为空且不能超过 120 个字符")
        }
        guard !input.category.isEmpty, input.category.count <= 80 else {
            throw SubTrackError.invalidInput("分类不能为空且不能超过 80 个字符")
        }
        guard input.channel.count <= 120 else {
            throw SubTrackError.invalidInput("购买渠道不能超过 120 个字符")
        }
        guard input.notes.count <= 3_000 else {
            throw SubTrackError.invalidInput("备注不能超过 3000 个字符")
        }
        guard allowedCurrencies.contains(input.currency) else {
            throw SubTrackError.invalidInput("请选择支持的币种")
        }
        guard (1 ... 36_500).contains(input.extensionDays) else {
            throw SubTrackError.invalidInput("有效期需介于 1 和 36500 天之间")
        }
        guard (0 ... 3_650).contains(input.reminderDays) else {
            throw SubTrackError.invalidInput("提醒天数需介于 0 和 3650 天之间")
        }
        try validateMoney(input.officialPrice, label: "官方价格")
        try validateMoney(input.thirdPartyReference, label: "第三方价格")
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
            preconditionFailure("两个有效日期无法计算日数")
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
        if official > 0, thirdParty > 0 { return min(official, thirdParty) }
        if official > 0 { return official }
        if thirdParty > 0 { return thirdParty }
        return nil
    }

    static func decisionPriceKind(for subscription: Subscription) -> String {
        if subscription.officialPrice > 0, subscription.thirdPartyReference > 0 {
            return "官方 / 第三方较低值"
        }
        if subscription.thirdPartyReference > 0 { return "第三方参考价" }
        if subscription.officialPrice > 0 { return "官方价格" }
        return "尚未设置价格"
    }

    private static func validateMoney(_ value: Decimal, label: String) throws {
        guard value >= 0, value <= 1_000_000_000 else {
            throw SubTrackError.invalidInput("\(label)需介于 0 和 1000000000 之间")
        }
    }
}

enum SubTrackEngine {
    static func recordPurchase(
        for subscription: Subscription,
        purchasedAt: Date,
        price: Decimal,
        extensionDays: Int,
        channel: String,
        notes: String,
        calendar: Calendar = .current,
        now: Date = Date()
    ) throws -> PurchaseRecord {
        let purchaseDay = calendar.startOfDay(for: purchasedAt)
        let today = calendar.startOfDay(for: now)
        guard price >= 0, price <= 1_000_000_000 else {
            throw SubTrackError.invalidInput("实付价格需介于 0 和 1000000000 之间")
        }
        guard purchaseDay <= today else {
            throw SubTrackError.invalidInput("购买日期不能晚于今天")
        }
        guard (1 ... 36_500).contains(extensionDays) else {
            throw SubTrackError.invalidInput("增加有效期需介于 1 和 36500 天之间")
        }
        let trimmedChannel = channel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedChannel.count <= 120, trimmedNotes.count <= 3_000 else {
            throw SubTrackError.invalidInput("购买渠道或备注过长")
        }

        // 未到期就从原到期日续，已到期则从购买日期续。
        let expiryDay = calendar.startOfDay(for: subscription.expiresAt)
        guard let newExpiry = calendar.date(
            byAdding: .day,
            value: extensionDays,
            to: max(expiryDay, purchaseDay)
        ) else {
            throw SubTrackError.invalidInput("续期后的到期时间超出支持范围")
        }
        let purchaseChannel = trimmedChannel.isEmpty
            ? subscription.channel
            : trimmedChannel

        return PurchaseRecord(
            purchasedAt: purchaseDay,
            price: price,
            currency: subscription.currency,
            channel: purchaseChannel,
            extensionDays: extensionDays,
            newExpiry: newExpiry,
            notes: trimmedNotes
        )
    }

    // 按续费周期推算未来支出，并按币种分别汇总。
    static func forecast(
        subscriptions: [Subscription],
        months: Int = 6,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ForecastSummary {
        let monthCount = min(max(months, 1), 24)
        let today = calendar.startOfDay(for: now)
        let current = calendar.dateComponents([.year, .month], from: today)
        guard let startYear = current.year,
              let startMonth = current.month,
              let start = calendar.date(from: DateComponents(year: startYear, month: startMonth, day: 1)),
              let end = calendar.date(byAdding: .month, value: monthCount, to: start),
              let next90 = calendar.date(byAdding: .day, value: 90, to: today),
              let next90Exclusive = calendar.date(byAdding: .day, value: 1, to: next90) else {
            return ForecastSummary(buckets: [], next90Days: [])
        }

        let horizon = max(end, next90Exclusive)
        var totalsByMonth: [Int: [String: Decimal]] = [:]
        var next90Totals: [String: Decimal] = [:]

        for item in subscriptions {
            guard let price = SubscriptionRules.decisionPrice(for: item), price > 0 else { continue }
            var renewal = max(calendar.startOfDay(for: item.expiresAt), today)
            while renewal < horizon {
                let components = calendar.dateComponents([.year, .month], from: renewal)
                guard let year = components.year, let month = components.month else { break }
                let offset = (year - startYear) * 12 + month - startMonth
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
        String(format: "%04d-%02d", year, month)
    }

    private static func currencyTotals(_ values: [String: Decimal]) -> [CurrencyTotal] {
        values
            .map { CurrencyTotal(currency: $0.key, total: $0.value.rounded()) }
            .sorted { $0.currency < $1.currency }
    }
}
