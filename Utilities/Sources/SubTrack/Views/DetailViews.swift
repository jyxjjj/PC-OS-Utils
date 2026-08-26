import SwiftUI

// 项目详情，包括当前状态和配置。
struct SubscriptionDetailView: View {
    @Environment(AppModel.self) private var model
    let subscription: Subscription

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppConstants.SubTrack.Detail.contentSpacing) {
                header()
                configuration()
            }
            .padding(AppConstants.SubTrack.Detail.contentPadding)
            .frame(maxWidth: AppConstants.SubTrack.Detail.maximumWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(subscription.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.presentedSheet = .editor(subscription)
                } label: {
                    Label(
                        AppConstants.Common.edit,
                        systemImage: "pencil"
                    )
                }
            }
        }
    }

    private func header() -> some View {
        let view = SubscriptionRules.view(for: subscription, now: model.clock)
        return HStack(alignment: .top, spacing: AppConstants.SubTrack.Detail.headerSpacing) {
            Text(String(subscription.name.prefix(1)).uppercased())
                .font(.title2.bold())
                .frame(
                    width: AppConstants.SubTrack.Detail.iconSize,
                    height: AppConstants.SubTrack.Detail.iconSize
                )
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(AppConstants.SubTrack.Detail.iconOpacity))
                .clipShape(
                    RoundedRectangle(cornerRadius: AppConstants.SubTrack.Detail.iconCornerRadius)
                )
            VStack(alignment: .leading, spacing: AppConstants.SubTrack.Detail.titleSpacing) {
                Text(subscription.name).font(.title.bold())
                Text(
                    String(
                        format: AppConstants.SubTrack.Detail.projectMetadataFormat,
                        subscription.category,
                        subscription.priority.localizedName,
                        subscription.channel.isEmpty
                            ? AppConstants.SubTrack.Detail.unsetChannel
                            : subscription.channel
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack(spacing: AppConstants.SubTrack.Detail.metadataSpacing) {
                    Label(
                        subscription.expiresAt.localizedDate,
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    Text(view.status.localizedName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(view.status.color)
                        .padding(
                            .horizontal,
                            AppConstants.SubTrack.Detail.statusHorizontalPadding
                        )
                        .padding(
                            .vertical,
                            AppConstants.SubTrack.Detail.statusVerticalPadding
                        )
                        .background(
                            view.status.color.opacity(AppConstants.SubTrack.Detail.statusOpacity)
                        )
                        .clipShape(Capsule())
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: AppConstants.SubTrack.Detail.priceSpacing) {
                Text(
                    SubscriptionRules.decisionPrice(for: subscription)?
                        .money(currency: subscription.currency) ?? AppConstants.Common.emDash
                )
                .font(.title3.bold())
                Text(SubscriptionRules.decisionPriceKind(for: subscription))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .subTrackCard()
    }

    private func configuration() -> some View {
        VStack(alignment: .leading, spacing: AppConstants.SubTrack.Detail.gridSpacing) {
            Text(AppConstants.SubTrack.Detail.projectConfiguration)
                .font(.title3.bold())
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: AppConstants.SubTrack.Detail.gridMinimumWidth),
                        alignment: .leading
                    )
                ],
                alignment: .leading,
                spacing: AppConstants.SubTrack.Detail.gridSpacing
            ) {
                detail(
                    AppConstants.SubTrack.Detail.renewalPeriod,
                    String(
                        format: AppConstants.SubTrack.Detail.daysFormat,
                        subscription.extensionDays
                    )
                )
                detail(
                    AppConstants.SubTrack.Detail.reminder,
                    String(
                        format: AppConstants.SubTrack.Detail.daysFormat,
                        subscription.reminderDays
                    )
                )
                detail(
                    AppConstants.SubTrack.Detail.officialPrice,
                    subscription.officialPrice > AppConstants.SubTrack.Rules.minimumMoney
                        ? subscription.officialPrice.money(currency: subscription.currency)
                        : AppConstants.SubTrack.Detail.unset
                )
                detail(
                    AppConstants.SubTrack.Detail.thirdPartyPrice,
                    subscription.thirdPartyReference > AppConstants.SubTrack.Rules.minimumMoney
                        ? subscription.thirdPartyReference.money(currency: subscription.currency)
                        : AppConstants.SubTrack.Detail.unset
                )
            }
            if !subscription.notes.isEmpty {
                Divider()
                Text(subscription.notes).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .subTrackCard()
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(
            alignment: .leading,
            spacing: AppConstants.SubTrack.Detail.rowSpacing
        ) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value).font(.body.weight(.semibold))
        }
    }
}
