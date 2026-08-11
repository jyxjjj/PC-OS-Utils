import Charts
import SwiftData
import SwiftUI

// 根视图，处理加载状态、弹窗和全局提示。
struct SubTrackContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model

        Group {
            if let container = model.container {
                NavigationStack { DashboardView() }
                    .modelContainer(container)
            } else {
                ContentUnavailableView {
                    Label("无法载入数据", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(model.initializationError ?? "无法创建 SubTrack 数据库")
                } actions: {
                    Button("重试") { model.initializeStore() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { @MainActor in
            await model.runDayChangeRefreshLoop()
        }
        .task(id: model.notice) { @MainActor in
            guard !model.notice.isEmpty else { return }
            do { try await Task.sleep(for: .milliseconds(3_500)) }
            catch { return }
            model.notice = ""
        }
        .sheet(item: $model.presentedSheet) { sheet in
            switch sheet {
            case let .editor(subscription):
                SubscriptionEditorView(subscription: subscription)
            case let .purchase(subscription):
                PurchaseView(subscription: subscription)
            }
        }
        .overlay(alignment: .bottom) {
            if !model.notice.isEmpty {
                Text(model.notice)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .foregroundStyle(.primary)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 8, y: 3)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.notice)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refreshForForeground()
            }
        }
    }
}

// 首页仪表盘：汇总、项目列表、提醒和支出预测。
private struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Subscription.expiresAt) private var subscriptions: [Subscription]

    var body: some View {
        let clock = model.clock
        let allViews = subscriptions.map {
            SubscriptionRules.view(for: $0, now: clock)
        }
        let forecast = SubTrackEngine.forecast(
            subscriptions: subscriptions,
            now: clock
        )
        let statusCounts = allViews.reduce(
            into: (active: 0, dueSoon: 0, expired: 0)
        ) { counts, view in
            switch view.status {
            case .active: counts.active += 1
            case .dueSoon: counts.dueSoon += 1
            case .expired: counts.expired += 1
            }
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                metrics(
                    active: statusCounts.active,
                    due: statusCounts.dueSoon,
                    expired: statusCounts.expired,
                    forecast: forecast
                )
                HStack(alignment: .top, spacing: 18) {
                    ProjectsPane(views: allViews)
                        .frame(maxWidth: .infinity, alignment: .top)
                    VStack(spacing: 18) {
                        ReminderCard(views: allViews)
                        ForecastCard(forecast: forecast)
                    }
                    .frame(width: 350)
                }
            }
            .padding(22)
            .frame(maxWidth: 1480)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("SubTrack")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.presentedSheet = .editor(nil)
                } label: {
                    Label("新建项目", systemImage: "plus")
                }
            }
        }
    }

    private func metrics(
        active: Int,
        due: Int,
        expired: Int,
        forecast: ForecastSummary
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
            MetricCard(title: "有效项目", value: "\(active)", note: "当前无需处理", color: .green)
            MetricCard(title: "即将到期", value: "\(due)", note: "已进入提醒窗口", color: .orange)
            MetricCard(title: "已到期", value: "\(expired)", note: "需要续费或删除", color: .red)
            MetricCard(
                title: "未来 90 天",
                value: forecast.next90Days.isEmpty
                    ? "暂无支出"
                    : forecast.next90Days.map { $0.total.money(currency: $0.currency) }.joined(separator: " · "),
                note: "按币种独立汇总",
                color: .blue,
                dark: true
            )
        }
    }
}

private struct ProjectsPane: View {
    @Environment(AppModel.self) private var model
    let views: [SubscriptionView]

    var body: some View {
        @Bindable var model = model
        projects(model.filteredViews(from: views))
            .searchable(text: $model.query, prompt: "搜索名称、分类、渠道或备注")
            .searchScopes($model.priorityFilter) {
                Text("全部优先级").tag(nil as SubscriptionPriority?)
                ForEach(SubscriptionPriority.allCases) { priority in
                    Text(priority.localizedName).tag(priority as SubscriptionPriority?)
                }
            }
    }

    private func projects(_ filteredViews: [SubscriptionView]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("订阅项目").font(.title3.bold())
                Text("按到期日排序 · \(filteredViews.count) 个结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if filteredViews.isEmpty {
                Group {
                    if views.isEmpty {
                        ContentUnavailableView {
                            Label("还没有项目", systemImage: "rectangle.stack")
                        } description: {
                            Text("创建项目后，可在这里查看到期日期和续费预测。")
                        } actions: {
                            Button("创建项目") {
                                model.presentedSheet = .editor(nil)
                            }
                        }
                    } else if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView.search(text: model.query)
                    } else {
                        ContentUnavailableView {
                            Label("没有符合条件的项目", systemImage: "line.3.horizontal.decrease.circle")
                        } description: {
                            Text("当前优先级范围内没有项目。")
                        } actions: {
                            Button("清除筛选") {
                                model.query = ""
                                model.priorityFilter = nil
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredViews) { SubscriptionRow(view: $0) }
                }
            }
        }
        .subTrackCard()
    }
}

private struct MetricCard: View {
    private static let forecastBanner = Color(red: 24 / 255, green: 58 / 255, blue: 122 / 255)

    let title: String
    let value: String
    let note: String
    let color: Color
    var dark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).opacity(0.8)
            Text(value)
                .font(.title2.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.68)
            Text(note).font(.caption).opacity(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .foregroundStyle(dark ? .white : .primary)
        .background(dark ? Self.forecastBanner : color.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// 单个项目的列表卡片和快捷操作。
private struct SubscriptionRow: View {
    @Environment(AppModel.self) private var model
    let view: SubscriptionView
    @State private var confirmDelete = false

    private var item: Subscription { view.subscription }

    var body: some View {
        HStack(spacing: 14) {
            NavigationLink {
                SubscriptionDetailView(subscription: item)
            } label: {
                HStack(spacing: 14) {
                    Text(String(item.name.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .frame(width: 38, height: 38)
                        .foregroundStyle(Color.accentColor)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(item.name).font(.headline)
                            Text(item.priority.localizedName)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                        Text("\(item.category) · \(item.expiresAt.localizedDate) · \(remainingText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(SubscriptionRules.decisionPrice(for: item)?.money(currency: item.currency) ?? "—")
                            .font(.headline)
                        Text(SubscriptionRules.decisionPriceKind(for: item))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(view.status.localizedName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(view.status.color)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(view.status.color.opacity(0.12))
                        .clipShape(Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("记录续费", systemImage: "cart") {
                    model.presentedSheet = .purchase(item)
                }
                Divider()
                Button("编辑", systemImage: "pencil") {
                    model.presentedSheet = .editor(item)
                }
                Button("删除", systemImage: "trash", role: .destructive) {
                    confirmDelete = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(12)
        .background(.background)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .alert("删除 \"\(item.name)\"？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("删除项目与全部历史", role: .destructive) {
                do { try model.remove(item) }
                catch { model.notice = "删除失败：\(error.localizedDescription)" }
            }
        } message: {
            Text("续费记录也会删除，此操作无法撤销。")
        }
    }

    private var remainingText: String {
        view.status == .expired ? "过期 \(-view.daysRemaining) 天" : "剩余 \(view.daysRemaining) 天"
    }
}

// 只展示即将到期或已经到期的项目。
private struct ReminderCard: View {
    let views: [SubscriptionView]

    var body: some View {
        let reminders = views
            .filter { $0.status != .active }

        VStack(alignment: .leading, spacing: 12) {
            Text("提醒").font(.headline)
            if reminders.isEmpty {
                Text("暂无提醒").foregroundStyle(.secondary)
            } else {
                ForEach(reminders) { view in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(view.status == .expired
                            ? "\(view.subscription.name) 已到期"
                            : "\(view.subscription.name) 即将到期")
                            .font(.caption.weight(.bold))
                        Text(view.status == .expired
                            ? "已过期 \(-view.daysRemaining) 天，请续费或删除项目。"
                            : "还剩 \(view.daysRemaining) 天，到期日为 \(view.subscription.expiresAt.localizedDate)。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if view.id != reminders.last?.id { Divider() }
                }
            }
        }
        .subTrackCard()
    }
}

// 用图表和明细展示未来六个月的预计支出。
private struct ForecastCard: View {
    let forecast: ForecastSummary

    var body: some View {
        let hasTotals = forecast.buckets.contains { !$0.totals.isEmpty }

        VStack(alignment: .leading, spacing: 12) {
            Text("未来 6 个月").font(.headline)
            if !hasTotals {
                Text("暂无可预测支出")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(forecast.buckets) { bucket in
                        ForEach(bucket.totals) { total in
                            BarMark(
                                x: .value("月份", bucket.month),
                                y: .value("金额", total.total.doubleValue)
                            )
                            .foregroundStyle(by: .value("币种", total.currency))
                        }
                    }
                }
                .frame(height: 160)
            }
            ForEach(forecast.buckets) { bucket in
                HStack {
                    Text(bucket.month).font(.caption.monospacedDigit())
                    Spacer()
                    Text(bucket.totals.isEmpty ? "—" : bucket.totals.map {
                        $0.total.money(currency: $0.currency)
                    }.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .subTrackCard()
    }
}
