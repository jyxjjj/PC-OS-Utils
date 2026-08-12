import Foundation
import SwiftUI

extension Decimal {
    func money(currency: String) -> String {
        formatted(
            Decimal.FormatStyle.Currency(
                code: currency,
                locale: Locale(identifier: AppConstants.SubTrack.Formatting.currencyLocale)
            )
            .precision(
                .fractionLength(
                    AppConstants.SubTrack.Formatting.minimumFractionDigits ...
                        AppConstants.SubTrack.Formatting.maximumFractionDigits
                )
            )
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
            .padding(AppConstants.SubTrack.Formatting.cardPadding)
            .background(.background)
            .overlay(
                RoundedRectangle(
                    cornerRadius: AppConstants.SubTrack.Formatting.cardCornerRadius
                )
                .stroke(
                    .quaternary,
                    lineWidth: AppConstants.SubTrack.Formatting.cardLineWidth
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppConstants.SubTrack.Formatting.cardCornerRadius
                )
            )
    }
}
