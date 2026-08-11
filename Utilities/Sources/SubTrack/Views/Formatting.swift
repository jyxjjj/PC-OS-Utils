import Foundation
import SwiftUI

extension Decimal {
    func money(currency: String) -> String {
        formatted(
            Decimal.FormatStyle.Currency(
                code: currency,
                locale: Locale(identifier: "zh_CN")
            )
            .precision(.fractionLength(0 ... 2))
        )
    }
}

extension Date {
    var localizedDate: String {
        formatted(
            Date.ISO8601FormatStyle(timeZone: .current)
                .year()
                .month()
                .day()
        )
    }
}

extension SubscriptionStatus {
    var color: Color {
        switch self {
        case .active: .green
        case .dueSoon: .orange
        case .expired: .red
        }
    }
}

extension View {
    func subTrackCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
