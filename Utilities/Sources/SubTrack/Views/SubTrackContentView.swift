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
                    Label(
                        AppConstants.SubTrack.Content.loadFailed,
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.title2.bold())
                } description: {
                    Text(
                        model.initializationError
                            ?? AppConstants.SubTrack.Content.createDatabaseFailed
                    )
                    .font(.body)
                } actions: {
                    Button(AppConstants.SubTrack.Content.retry) { model.initializeStore() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { @MainActor in
            await model.runDayChangeRefreshLoop()
        }
        .task(id: model.notice) { @MainActor in
            guard !model.notice.isEmpty else { return }
            do {
                try await Task.sleep(
                    for: .milliseconds(AppConstants.SubTrack.Content.noticeMilliseconds)
                )
            } catch { return }
            model.notice = ""
        }
        .sheet(item: $model.presentedSheet) { sheet in
            switch sheet {
                case .editor(let subscription):
                    SubscriptionEditorView(subscription: subscription)
            }
        }
        .overlay(alignment: .bottom) {
            if !model.notice.isEmpty {
                Text(model.notice)
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, AppConstants.SubTrack.Content.noticeHorizontalPadding)
                    .padding(.vertical, AppConstants.SubTrack.Content.noticeVerticalPadding)
                    .foregroundStyle(.primary)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, AppConstants.SubTrack.Content.noticeBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            .easeOut(duration: AppConstants.SubTrack.Content.noticeAnimationDuration),
            value: model.notice
        )
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refreshForForeground()
            }
        }
    }
}

// 首页仪表盘: 汇总、项目列表、提醒和支出预测。
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
            VStack(alignment: .leading, spacing: AppConstants.SubTrack.Content.sectionSpacing) {
                metrics(
                    active: statusCounts.active,
                    due: statusCounts.dueSoon,
                    expired: statusCounts.expired,
                    forecast: forecast
                )
                HStack(alignment: .top, spacing: AppConstants.SubTrack.Content.sectionSpacing) {
                    ProjectsPane(views: allViews)
                        .frame(maxWidth: .infinity, alignment: .top)
                    VStack(spacing: AppConstants.SubTrack.Content.sectionSpacing) {
                        ReminderCard(views: allViews)
                        ForecastCard(forecast: forecast)
                    }
                    .frame(width: AppConstants.SubTrack.Content.sidebarWidth)
                }
            }
            .padding(AppConstants.SubTrack.Content.contentPadding)
            .frame(maxWidth: AppConstants.SubTrack.Content.maximumContentWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(AppConstants.SubTrack.Content.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.presentedSheet = .editor(nil)
                } label: {
                    Label(
                        AppConstants.SubTrack.Content.newProject,
                        systemImage: "plus"
                    )
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
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: AppConstants.SubTrack.Content.metricMinimumWidth),
                    spacing: AppConstants.SubTrack.Content.metricGridSpacing
                )
            ],
            spacing: AppConstants.SubTrack.Content.metricGridSpacing
        ) {
            MetricCard(
                title: AppConstants.SubTrack.Content.activeProjects,
                value: String(active),
                note: AppConstants.SubTrack.Content.activeProjectsNote,
                color: .green
            )
            MetricCard(
                title: AppConstants.SubTrack.Content.dueSoonProjects,
                value: String(due),
                note: AppConstants.SubTrack.Content.dueSoonProjectsNote,
                color: .orange
            )
            MetricCard(
                title: AppConstants.SubTrack.Content.expiredProjects,
                value: String(expired),
                note: AppConstants.SubTrack.Content.expiredProjectsNote,
                color: .red
            )
            MetricCard(
                title: AppConstants.SubTrack.Content.next90Days,
                value: forecast.next90Days.isEmpty
                    ? AppConstants.SubTrack.Content.noExpenses
                    : forecast.next90Days.map {
                        $0.total.money(currency: $0.currency)
                    }.joined(separator: AppConstants.Common.itemSeparator),
                note: AppConstants.SubTrack.Content.totalsByCurrency,
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
            .searchable(
                text: $model.query,
                prompt: AppConstants.SubTrack.Content.searchPrompt
            )
            .searchScopes($model.priorityFilter) {
                Text(AppConstants.SubTrack.Content.allPriorities)
                    .tag(nil as SubscriptionPriority?)
                ForEach(SubscriptionPriority.allCases) { priority in
                    Text(priority.localizedName).tag(priority as SubscriptionPriority?)
                }
            }
    }

    private func projects(_ filteredViews: [SubscriptionView]) -> some View {
        VStack(
            alignment: .leading,
            spacing: AppConstants.SubTrack.Content.projectsContentSpacing
        ) {
            VStack(
                alignment: .leading,
                spacing: AppConstants.SubTrack.Content.projectTitleSpacing
            ) {
                Text(AppConstants.SubTrack.Content.subscriptions)
                    .font(.title3.bold())
                Text(
                    String(
                        format: AppConstants.SubTrack.Content.sortedResultFormat,
                        filteredViews.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if filteredViews.isEmpty {
                Group {
                    if views.isEmpty {
                        ContentUnavailableView {
                            Label(
                                AppConstants.SubTrack.Content.noProjects,
                                systemImage: "rectangle.stack"
                            )
                            .font(.title3.bold())
                        } description: {
                            Text(AppConstants.SubTrack.Content.noProjectsDescription)
                                .font(.body)
                        } actions: {
                            Button(AppConstants.SubTrack.Content.createProject) {
                                model.presentedSheet = .editor(nil)
                            }
                        }
                    } else if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView.search(text: model.query)
                    } else {
                        ContentUnavailableView {
                            Label(
                                AppConstants.SubTrack.Content.noMatches,
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                            .font(.title3.bold())
                        } description: {
                            Text(AppConstants.SubTrack.Content.noMatchesDescription)
                                .font(.body)
                        } actions: {
                            Button(AppConstants.SubTrack.Content.clearFilter) {
                                model.query = ""
                                model.priorityFilter = nil
                            }
                        }
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: AppConstants.SubTrack.Content.emptyMinimumHeight
                )
            } else {
                LazyVStack(spacing: AppConstants.SubTrack.Content.rowSpacing) {
                    ForEach(filteredViews) { SubscriptionRow(view: $0) }
                }
            }
        }
        .subTrackCard()
    }
}

private struct MetricCard: View {
    private static let forecastBanner = Color(
        red: 24 / 255,
        green: 58 / 255,
        blue: 122 / 255
    )

    let title: String
    let value: String
    let note: String
    let color: Color
    var dark = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.SubTrack.Content.metricCardSpacing) {
            Text(title)
                .font(.body.weight(.semibold))
                .opacity(AppConstants.SubTrack.Content.metricTitleOpacity)
            Text(value)
                .font(.title2.bold())
                .lineLimit(AppConstants.SubTrack.Content.metricLineLimit)
                .minimumScaleFactor(AppConstants.SubTrack.Content.metricMinimumScale)
            Text(note)
                .font(.caption)
                .opacity(AppConstants.SubTrack.Content.metricNoteOpacity)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: AppConstants.SubTrack.Content.metricMinimumHeight,
            alignment: .leading
        )
        .padding(AppConstants.SubTrack.Content.metricPadding)
        .foregroundStyle(dark ? .white : .primary)
        .background(
            dark
                ? Self.forecastBanner
                : color.opacity(AppConstants.SubTrack.Content.metricBackgroundOpacity)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: AppConstants.SubTrack.Content.metricCornerRadius)
        )
    }
}

// 单个项目的列表卡片和快捷操作。
private struct SubscriptionRow: View {
    @Environment(AppModel.self) private var model
    let view: SubscriptionView
    @State private var confirmDelete = false

    private var item: Subscription { view.subscription }

    var body: some View {
        HStack(spacing: AppConstants.SubTrack.Content.subscriptionRowSpacing) {
            NavigationLink {
                SubscriptionDetailView(subscription: item)
            } label: {
                HStack(spacing: AppConstants.SubTrack.Content.subscriptionRowSpacing) {
                    Text(String(item.name.prefix(1)).uppercased())
                        .font(.body.bold())
                        .frame(
                            width: AppConstants.SubTrack.Content.rowIconSize,
                            height: AppConstants.SubTrack.Content.rowIconSize
                        )
                        .foregroundStyle(Color.accentColor)
                        .background(
                            Color.accentColor.opacity(AppConstants.SubTrack.Content.rowIconOpacity)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: AppConstants.SubTrack.Content.rowIconCornerRadius
                            )
                        )
                    VStack(
                        alignment: .leading,
                        spacing: AppConstants.SubTrack.Content.rowTitleSpacing
                    ) {
                        HStack(spacing: AppConstants.SubTrack.Content.prioritySpacing) {
                            Text(item.name)
                                .font(.headline.weight(.semibold))
                            Text(item.priority.localizedName)
                                .font(.caption.weight(.bold))
                                .padding(
                                    .horizontal,
                                    AppConstants.SubTrack.Content.priorityHorizontalPadding
                                )
                                .padding(
                                    .vertical,
                                    AppConstants.SubTrack.Content.priorityVerticalPadding
                                )
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                        Text(
                            String(
                                format: AppConstants.SubTrack.Content.projectMetadataFormat,
                                item.category,
                                item.expiresAt.localizedDate,
                                remainingText
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(
                        alignment: .trailing,
                        spacing: AppConstants.SubTrack.Content.priceSpacing
                    ) {
                        Text(
                            SubscriptionRules.decisionPrice(for: item)?
                                .money(currency: item.currency) ?? AppConstants.Common.emDash
                        )
                        .font(.body.weight(.semibold))
                        Text(SubscriptionRules.decisionPriceKind(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(view.status.localizedName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(view.status.color)
                        .padding(
                            .horizontal,
                            AppConstants.SubTrack.Content.statusHorizontalPadding
                        )
                        .padding(
                            .vertical,
                            AppConstants.SubTrack.Content.statusVerticalPadding
                        )
                        .background(
                            view.status.color.opacity(AppConstants.SubTrack.Content.statusOpacity)
                        )
                        .clipShape(Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button(
                    AppConstants.Common.edit,
                    systemImage: "pencil"
                ) {
                    model.presentedSheet = .editor(item)
                }
                Button(
                    AppConstants.Common.delete,
                    systemImage: "trash",
                    role: .destructive
                ) {
                    confirmDelete = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(
                        width: AppConstants.SubTrack.Content.menuSize,
                        height: AppConstants.SubTrack.Content.menuSize
                    )
            }
            .menuStyle(.borderlessButton)
        }
        .padding(AppConstants.SubTrack.Content.rowPadding)
        .background(.background)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.SubTrack.Content.rowCornerRadius)
                .stroke(.quaternary)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: AppConstants.SubTrack.Content.rowCornerRadius)
        )
        .alert(
            String(format: AppConstants.SubTrack.Content.deleteTitleFormat, item.name),
            isPresented: $confirmDelete
        ) {
            Button(AppConstants.Common.cancel, role: .cancel) {}
            Button(AppConstants.SubTrack.Content.deleteProject, role: .destructive) {
                do { try model.remove(item) } catch {
                    model.notice = String(
                        format: AppConstants.SubTrack.Content.deleteFailedFormat,
                        error.localizedDescription
                    )
                }
            }
        } message: {
            Text(AppConstants.SubTrack.Content.deleteDescription)
        }
    }

    private var remainingText: String {
        view.status == .expired
            ? String(
                format: AppConstants.SubTrack.Content.expiredDaysFormat,
                -view.daysRemaining
            )
            : String(
                format: AppConstants.SubTrack.Content.remainingDaysFormat,
                view.daysRemaining
            )
    }
}

// 只展示即将到期或已经到期的项目。
private struct ReminderCard: View {
    let views: [SubscriptionView]

    var body: some View {
        let reminders =
            views
            .filter { $0.status != .active }

        VStack(alignment: .leading, spacing: AppConstants.SubTrack.Content.reminderCardSpacing) {
            Text(AppConstants.SubTrack.Content.reminders)
                .font(.title3.bold())
            if reminders.isEmpty {
                Text(AppConstants.SubTrack.Content.noReminders).foregroundStyle(.secondary)
            } else {
                ForEach(reminders) { view in
                    VStack(
                        alignment: .leading,
                        spacing: AppConstants.SubTrack.Content.rowTitleSpacing
                    ) {
                        Text(
                            String(
                                format: view.status == .expired
                                    ? AppConstants.SubTrack.Content.expiredTitleFormat
                                    : AppConstants.SubTrack.Content.dueSoonTitleFormat,
                                view.subscription.name
                            )
                        )
                        .font(.caption.weight(.bold))
                        Text(
                            view.status == .expired
                                ? String(
                                    format: AppConstants.SubTrack.Content.overdueDescriptionFormat,
                                    -view.daysRemaining
                                )
                                : String(
                                    format: AppConstants.SubTrack.Content.dueSoonDescriptionFormat,
                                    view.daysRemaining,
                                    view.subscription.expiresAt.localizedDate
                                )
                        )
                        .font(.caption)
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

        VStack(alignment: .leading, spacing: AppConstants.SubTrack.Content.forecastCardSpacing) {
            Text(AppConstants.SubTrack.Content.nextSixMonths)
                .font(.title3.bold())
            if !hasTotals {
                Text(AppConstants.SubTrack.Content.noForecast)
                    .foregroundStyle(.secondary)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: AppConstants.SubTrack.Content.forecastEmptyMinimumHeight
                    )
            } else {
                Chart {
                    ForEach(forecast.buckets) { bucket in
                        ForEach(bucket.totals) { total in
                            BarMark(
                                x: .value(
                                    AppConstants.SubTrack.Content.chartMonth,
                                    bucket.month
                                ),
                                y: .value(
                                    AppConstants.SubTrack.Content.chartAmount,
                                    total.total.doubleValue
                                )
                            )
                            .foregroundStyle(
                                by: .value(
                                    AppConstants.SubTrack.Content.chartCurrency,
                                    total.currency
                                )
                            )
                        }
                    }
                }
                .frame(height: AppConstants.SubTrack.Content.chartHeight)
            }
            ForEach(forecast.buckets) { bucket in
                HStack {
                    Text(bucket.month)
                        .font(.caption.monospacedDigit())
                    Spacer()
                    Text(
                        bucket.totals.isEmpty
                            ? AppConstants.Common.emDash
                            : bucket.totals.map {
                                $0.total.money(currency: $0.currency)
                            }.joined(separator: AppConstants.Common.itemSeparator)
                    )
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .subTrackCard()
    }
}
