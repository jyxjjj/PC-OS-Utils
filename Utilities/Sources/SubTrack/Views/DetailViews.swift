import SwiftData
import SwiftUI

// 项目详情，包括配置和续费历史。
struct SubscriptionDetailView: View {
    @Environment(AppModel.self) private var model
    let subscription: Subscription

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header()
                configuration()
                purchaseHistory()
            }
            .padding(22)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(subscription.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.presentedSheet = .purchase(subscription)
                } label: {
                    Label("记录续费", systemImage: "cart")
                }
                Button {
                    model.presentedSheet = .editor(subscription)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
            }
        }
    }

    private func header() -> some View {
        let view = SubscriptionRules.view(for: subscription, now: model.clock)
        return HStack(alignment: .top, spacing: 18) {
            Text(String(subscription.name.prefix(1)).uppercased())
                .font(.system(size: 28, weight: .bold))
                .frame(width: 58, height: 58)
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 6) {
                Text(subscription.name).font(.title2.bold())
                Text("\(subscription.category) · \(subscription.priority.localizedName) · \(subscription.channel.isEmpty ? "未设置渠道" : subscription.channel)")
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Label(subscription.expiresAt.localizedDate, systemImage: "calendar")
                    Text(view.status.localizedName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(view.status.color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(view.status.color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(
                    SubscriptionRules.decisionPrice(for: subscription)?
                        .money(currency: subscription.currency) ?? "—"
                )
                    .font(.title3.bold())
                Text(SubscriptionRules.decisionPriceKind(for: subscription))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .subTrackCard()
    }

    private func configuration() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("项目配置").font(.headline)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), alignment: .leading)],
                alignment: .leading,
                spacing: 12
            ) {
                detail("单次续费", "\(subscription.extensionDays) 天")
                detail("提前提醒", "\(subscription.reminderDays) 天")
                detail(
                    "官方价格",
                    subscription.officialPrice > 0
                        ? subscription.officialPrice.money(currency: subscription.currency)
                        : "未设置"
                )
                detail(
                    "第三方参考价",
                    subscription.thirdPartyReference > 0
                        ? subscription.thirdPartyReference.money(currency: subscription.currency)
                        : "未设置"
                )
            }
            if !subscription.notes.isEmpty {
                Divider()
                Text(subscription.notes).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .subTrackCard()
    }

    private func purchaseHistory() -> some View {
        let purchases = subscription.purchases.sorted { $0.purchasedAt > $1.purchasedAt }
        return VStack(alignment: .leading, spacing: 12) {
            Text("续费历史").font(.headline)
            if purchases.isEmpty {
                Text("暂无续费记录").foregroundStyle(.secondary)
            } else {
                ForEach(purchases) { purchase in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(purchase.purchasedAt.localizedDate).font(.subheadline.weight(.semibold))
                            Text("\(purchase.channel) · 延长 \(purchase.extensionDays) 天 · 新到期日 \(purchase.newExpiry.localizedDate)")
                                .font(.caption).foregroundStyle(.secondary)
                            if !purchase.notes.isEmpty { Text(purchase.notes).font(.caption) }
                        }
                        Spacer()
                        Text(purchase.price.money(currency: purchase.currency)).font(.subheadline.bold())
                    }
                    if purchase.persistentModelID != purchases.last?.persistentModelID { Divider() }
                }
            }
        }
        .subTrackCard()
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
    }
}
