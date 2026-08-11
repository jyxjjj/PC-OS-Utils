import SwiftUI

// 给必填字段补一个红色星号。
private struct SubTrackRequiredFieldLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
            Text("*").foregroundStyle(.red)
        }
    }
}

private let editorDateFormat = Date.VerbatimFormatStyle(
    format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
    locale: Locale(identifier: "en_US_POSIX"),
    timeZone: .current,
    calendar: Calendar(identifier: .gregorian)
)

// 文本框负责固定格式，弹出式 DatePicker 负责日历选择。
private struct EditorDateField: View {
    @Binding var selection: Date
    @State private var showingPicker = false

    var body: some View {
        HStack(spacing: 6) {
            TextField("日期", value: $selection, format: editorDateFormat)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 92)
            Button {
                showingPicker.toggle()
            } label: {
                Image(systemName: "calendar")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingPicker) {
                DatePicker("日期", selection: $selection, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()
            }
        }
    }
}

// 数字字段使用可选值，让空输入与 0 保持不同语义。
private struct SubscriptionDraft: Equatable {
    var name: String
    var category: String
    var expiry: Date
    var extensionDays: Int?
    var officialPrice: Decimal?
    var thirdPartyReference: Decimal?
    var channel: String
    var priority: SubscriptionPriority
    var notes: String
    var currency: String
    var reminderDays: Int?

    init(subscription: Subscription?) {
        let input = subscription?.input ?? SubscriptionInput()
        name = input.name
        category = input.category
        expiry = input.expiresAt
        extensionDays = subscription == nil ? nil : input.extensionDays
        officialPrice = input.officialPrice == 0 ? nil : input.officialPrice
        thirdPartyReference = input.thirdPartyReference == 0 ? nil : input.thirdPartyReference
        channel = input.channel
        priority = input.priority
        notes = input.notes
        currency = input.currency
        reminderDays = input.reminderDays
    }

    var hasMoney: Bool {
        officialPrice != nil || thirdPartyReference != nil
    }

    func input() throws -> SubscriptionInput {
        guard let extensionDays, let reminderDays else {
            throw SubTrackError.invalidInput("有效期和提醒天数必须是整数")
        }
        return SubscriptionInput(
            name: name,
            category: category,
            expiresAt: expiry,
            extensionDays: extensionDays,
            officialPrice: officialPrice ?? 0,
            thirdPartyReference: thirdPartyReference ?? 0,
            channel: channel,
            priority: priority,
            notes: notes,
            currency: currency,
            reminderDays: reminderDays
        )
    }
}

// 新建和编辑项目共用的表单。
struct SubscriptionEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let subscription: Subscription?
    private let initialDraft: SubscriptionDraft
    @State private var draft: SubscriptionDraft
    @State private var errorMessage = ""
    @State private var confirmDiscard = false
    @State private var pendingCurrency: String?

    init(subscription: Subscription?) {
        self.subscription = subscription
        let value = SubscriptionDraft(subscription: subscription)
        initialDraft = value
        _draft = State(initialValue: value)
    }

    private var dirty: Bool { draft != initialDraft }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField(text: $draft.name) { SubTrackRequiredFieldLabel(title: "名称") }
                    TextField(text: $draft.category, prompt: Text("VPS / 软件 / 会员")) {
                        SubTrackRequiredFieldLabel(title: "分类")
                    }
                    LabeledContent {
                        EditorDateField(selection: $draft.expiry)
                    } label: {
                        SubTrackRequiredFieldLabel(title: "到期日期")
                    }
                    TextField(value: $draft.extensionDays, format: .number) {
                        SubTrackRequiredFieldLabel(title: "单次续费天数")
                    }
                    Picker(selection: $draft.priority) {
                        ForEach(SubscriptionPriority.allCases) { Text($0.localizedName).tag($0) }
                    } label: {
                        SubTrackRequiredFieldLabel(title: "优先级")
                    }
                    TextField("购买渠道", text: $draft.channel)
                    TextField("备注", text: $draft.notes, axis: .vertical).lineLimit(3 ... 8)
                }
                Section("价格与提醒") {
                    Picker(selection: currencyBinding) {
                        ForEach(SubscriptionRules.allowedCurrencies, id: \.self) { Text($0).tag($0) }
                    } label: {
                        SubTrackRequiredFieldLabel(title: "币种")
                    }
                    TextField("官方价格", value: $draft.officialPrice, format: .number)
                    TextField("第三方参考价", value: $draft.thirdPartyReference, format: .number)
                    TextField(value: $draft.reminderDays, format: .number) {
                        SubTrackRequiredFieldLabel(title: "提前提醒天数")
                    }
                }
                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(subscription == nil ? "新增项目" : "编辑项目")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { requestClose() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("保存") { save() }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 520)
        .interactiveDismissDisabled(dirty)
        .alert("放弃未保存的更改？", isPresented: $confirmDiscard) {
            Button("继续编辑", role: .cancel) {}
            Button("放弃", role: .destructive) { dismiss() }
        }
        .alert("切换币种会清空金额", isPresented: Binding(
            get: { pendingCurrency != nil },
            set: { if !$0 { pendingCurrency = nil } }
        )) {
            Button("取消", role: .cancel) { pendingCurrency = nil }
            Button("切换并清空", role: .destructive) {
                if let currency = pendingCurrency {
                    draft.currency = currency
                    draft.officialPrice = nil
                    draft.thirdPartyReference = nil
                }
                pendingCurrency = nil
            }
        } message: {
            Text("SubTrack 不会自动换汇。")
        }
    }

    private var currencyBinding: Binding<String> {
        Binding(get: { draft.currency }, set: { currency in
            guard currency != draft.currency else { return }
            // 已填写金额时先确认，防止换币种后数值含义出错。
            if draft.hasMoney { pendingCurrency = currency }
            else { draft.currency = currency }
        })
    }

    private func requestClose() {
        if dirty { confirmDiscard = true } else { dismiss() }
    }

    private func save() {
        errorMessage = ""
        do {
            try model.saveSubscription(draft.input(), subscription: subscription)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// 记录续费，并顺延项目到期时间。
struct PurchaseView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let subscription: Subscription
    @State private var price: Decimal?
    @State private var days: Int?
    @State private var channel: String
    @State private var notes = ""
    @State private var purchasedAt: Date
    @State private var errorMessage = ""
    @State private var confirmDiscard = false
    private let initialPrice: Decimal?
    private let initialDate: Date

    init(subscription: Subscription) {
        self.subscription = subscription
        let price = SubscriptionRules.decisionPrice(for: subscription)
        let now = Date()
        initialPrice = price
        initialDate = now
        _price = State(initialValue: price)
        _days = State(initialValue: subscription.extensionDays)
        _channel = State(initialValue: subscription.channel)
        _purchasedAt = State(initialValue: now)
    }

    private var dirty: Bool {
        price != initialPrice || days != subscription.extensionDays ||
            channel != subscription.channel || !notes.isEmpty || purchasedAt != initialDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(value: $price, format: .number) {
                        SubTrackRequiredFieldLabel(title: "实付价格（\(subscription.currency)）")
                    }
                    TextField(value: $days, format: .number) {
                        SubTrackRequiredFieldLabel(title: "增加有效期（天）")
                    }
                    TextField("购买渠道", text: $channel)
                    LabeledContent {
                        EditorDateField(selection: $purchasedAt)
                    } label: {
                        SubTrackRequiredFieldLabel(title: "购买日期")
                    }
                    TextField("备注", text: $notes, axis: .vertical).lineLimit(2 ... 6)
                }
                Section {
                    Text("续费后会顺延到期日，提醒状态会根据新到期时间自动更新。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !errorMessage.isEmpty { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .formStyle(.grouped)
            .navigationTitle("记录续费 · \(subscription.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { requestClose() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("保存") { save() }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .interactiveDismissDisabled(dirty)
        .alert("放弃未保存的续费记录？", isPresented: $confirmDiscard) {
            Button("继续编辑", role: .cancel) {}
            Button("放弃", role: .destructive) { dismiss() }
        }
    }

    private func requestClose() {
        if dirty { confirmDiscard = true } else { dismiss() }
    }

    private func save() {
        guard let price, let days else {
            errorMessage = "请输入有效的价格和增加天数"
            return
        }
        do {
            try model.recordPurchase(
                subscription: subscription,
                purchasedAt: purchasedAt,
                price: price,
                extensionDays: days,
                channel: channel,
                notes: notes
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
