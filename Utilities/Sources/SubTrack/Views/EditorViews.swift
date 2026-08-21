import SwiftUI

// 给必填字段补一个红色星号。
private struct SubTrackRequiredFieldLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: AppConstants.SubTrack.Editor.requiredFieldSpacing) {
            Text(title)
            Text(AppConstants.Common.requiredFieldMarker).foregroundStyle(.red)
        }
        .font(AppConstants.Typography.p)
    }
}

private struct SubTrackFieldError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(AppConstants.Typography.span)
                .foregroundStyle(.red)
        }
    }
}

private struct SubTrackPresentedFieldError {
    let field: SubTrackInputField
    let message: String
}

// 文本框负责固定格式，弹出式 DatePicker 负责日历选择。
private struct EditorDateField: View {
    @Binding var selection: Date
    @State private var showingPicker = false

    var body: some View {
        HStack(spacing: AppConstants.SubTrack.Editor.dateFieldSpacing) {
            TextField(
                AppConstants.SubTrack.Editor.date,
                value: $selection,
                format: AppConstants.SubTrack.Formatting.editorDateFormat
            )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: AppConstants.SubTrack.Editor.dateFieldWidth)
            Button {
                showingPicker.toggle()
            } label: {
                Image(systemName: "calendar")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingPicker) {
                DatePicker(
                    AppConstants.SubTrack.Editor.date,
                    selection: $selection,
                    displayedComponents: [.date]
                )
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
        officialPrice = input.officialPrice == AppConstants.SubTrack.Rules.minimumMoney
            ? nil
            : input.officialPrice
        thirdPartyReference = input.thirdPartyReference == AppConstants.SubTrack.Rules.minimumMoney
            ? nil
            : input.thirdPartyReference
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
        guard let extensionDays else {
            throw SubTrackError.invalidInput(
                .extensionDays,
                AppConstants.SubTrack.Editor.invalidExtensionDaysInteger
            )
        }
        guard let reminderDays else {
            throw SubTrackError.invalidInput(
                .reminderDays,
                AppConstants.SubTrack.Editor.invalidReminderDaysInteger
            )
        }
        return SubscriptionInput(
            name: name,
            category: category,
            expiresAt: expiry,
            extensionDays: extensionDays,
            officialPrice: officialPrice ?? AppConstants.SubTrack.Rules.minimumMoney,
            thirdPartyReference: thirdPartyReference
                ?? AppConstants.SubTrack.Rules.minimumMoney,
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
    @State private var fieldError: SubTrackPresentedFieldError?
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
        VStack(spacing: 0) {
            HStack {
                Text(
                    subscription == nil
                        ? AppConstants.SubTrack.Editor.addTitle
                        : AppConstants.SubTrack.Editor.editTitle
                )
                .font(AppConstants.Typography.h3.bold())
                Spacer()
            }
            .padding()

            Divider()

            Form {
                Section {
                    VStack(alignment: .leading) {
                        TextField(text: validatedBinding(\.name, field: .name)) {
                            SubTrackRequiredFieldLabel(title: AppConstants.SubTrack.Editor.name)
                        }
                        SubTrackFieldError(message: errorMessage(for: .name))
                    }
                    VStack(alignment: .leading) {
                        TextField(
                            text: validatedBinding(\.category, field: .category),
                            prompt: Text(AppConstants.SubTrack.Editor.categoryPrompt)
                        ) {
                            SubTrackRequiredFieldLabel(
                                title: AppConstants.SubTrack.Editor.category
                            )
                        }
                        SubTrackFieldError(message: errorMessage(for: .category))
                    }
                    LabeledContent {
                        EditorDateField(selection: $draft.expiry)
                    } label: {
                        SubTrackRequiredFieldLabel(
                            title: AppConstants.SubTrack.Editor.expirationDate
                        )
                    }
                    VStack(alignment: .leading) {
                        TextField(
                            value: validatedBinding(\.extensionDays, field: .extensionDays),
                            format: .number
                        ) {
                            SubTrackRequiredFieldLabel(
                                title: AppConstants.SubTrack.Editor.extensionDays
                            )
                        }
                        SubTrackFieldError(message: errorMessage(for: .extensionDays))
                    }
                    Picker(selection: $draft.priority) {
                        ForEach(SubscriptionPriority.allCases) { Text($0.localizedName).tag($0) }
                    } label: {
                        SubTrackRequiredFieldLabel(title: AppConstants.SubTrack.Editor.priority)
                    }
                    VStack(alignment: .leading) {
                        TextField(
                            AppConstants.SubTrack.Editor.purchaseChannel,
                            text: validatedBinding(\.channel, field: .channel)
                        )
                        SubTrackFieldError(message: errorMessage(for: .channel))
                    }
                    VStack(alignment: .leading) {
                        TextField(
                            AppConstants.SubTrack.Editor.notes,
                            text: validatedBinding(\.notes, field: .notes),
                            axis: .vertical
                        )
                        .lineLimit(
                            AppConstants.SubTrack.Editor.subscriptionNotesMinimumLines ...
                                AppConstants.SubTrack.Editor.subscriptionNotesMaximumLines
                        )
                        SubTrackFieldError(message: errorMessage(for: .notes))
                    }
                } header: {
                    Text(AppConstants.SubTrack.Editor.basicInformation)
                        .font(AppConstants.Typography.h5.bold())
                }
                Section {
                    VStack(alignment: .leading) {
                        Picker(selection: currencyBinding) {
                            ForEach(AppConstants.SubTrack.currencyCodes, id: \.self) {
                                Text($0).tag($0)
                            }
                        } label: {
                            SubTrackRequiredFieldLabel(
                                title: AppConstants.SubTrack.Editor.currency
                            )
                        }
                        SubTrackFieldError(message: errorMessage(for: .currency))
                    }
                    VStack(alignment: .leading) {
                        TextField(
                            AppConstants.SubTrack.Editor.officialPrice,
                            value: validatedBinding(\.officialPrice, field: .officialPrice),
                            format: .number
                        )
                        SubTrackFieldError(message: errorMessage(for: .officialPrice))
                    }
                    VStack(alignment: .leading) {
                        TextField(
                            AppConstants.SubTrack.Editor.thirdPartyPrice,
                            value: validatedBinding(
                                \.thirdPartyReference,
                                field: .thirdPartyPrice
                            ),
                            format: .number
                        )
                        SubTrackFieldError(message: errorMessage(for: .thirdPartyPrice))
                    }
                    VStack(alignment: .leading) {
                        TextField(
                            value: validatedBinding(\.reminderDays, field: .reminderDays),
                            format: .number
                        ) {
                            SubTrackRequiredFieldLabel(
                                title: AppConstants.SubTrack.Editor.reminderDays
                            )
                        }
                        SubTrackFieldError(message: errorMessage(for: .reminderDays))
                    }
                } header: {
                    Text(AppConstants.SubTrack.Editor.priceAndReminder)
                        .font(AppConstants.Typography.h5.bold())
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(AppConstants.Typography.span)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button(AppConstants.Common.cancel) { requestClose() }
                    .keyboardShortcut(.cancelAction)
                Button(AppConstants.Common.save) { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(
            minWidth: AppConstants.SubTrack.Editor.subscriptionMinimumWidth,
            minHeight: AppConstants.SubTrack.Editor.subscriptionMinimumHeight,
            idealHeight: AppConstants.SubTrack.Editor.subscriptionIdealHeight
        )
        .interactiveDismissDisabled(dirty)
        .alert(AppConstants.SubTrack.Editor.discardChangesTitle, isPresented: $confirmDiscard) {
            Button(AppConstants.SubTrack.Editor.continueEditing, role: .cancel) {}
            Button(AppConstants.SubTrack.Editor.discard, role: .destructive) { dismiss() }
        }
        .alert(AppConstants.SubTrack.Editor.currencyChangeTitle, isPresented: Binding(
            get: { pendingCurrency != nil },
            set: { if !$0 { pendingCurrency = nil } }
        )) {
            Button(AppConstants.Common.cancel, role: .cancel) { pendingCurrency = nil }
            Button(AppConstants.SubTrack.Editor.changeAndClear, role: .destructive) {
                if let currency = pendingCurrency {
                    draft.currency = currency
                    draft.officialPrice = nil
                    draft.thirdPartyReference = nil
                    clearFieldError(for: .currency)
                    clearFieldError(for: .officialPrice)
                    clearFieldError(for: .thirdPartyPrice)
                }
                pendingCurrency = nil
            }
        } message: {
            Text(AppConstants.SubTrack.Editor.noCurrencyConversion)
        }
    }

    private var currencyBinding: Binding<String> {
        Binding(get: { draft.currency }, set: { currency in
            guard currency != draft.currency else { return }
            // 已填写金额时先确认，防止换币种后数值含义出错。
            if draft.hasMoney { pendingCurrency = currency }
            else {
                draft.currency = currency
                clearFieldError(for: .currency)
            }
        })
    }

    private func validatedBinding<Value>(
        _ keyPath: WritableKeyPath<SubscriptionDraft, Value>,
        field: SubTrackInputField
    ) -> Binding<Value> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                draft[keyPath: keyPath] = value
                clearFieldError(for: field)
            }
        )
    }

    private func errorMessage(for field: SubTrackInputField) -> String? {
        guard fieldError?.field == field else { return nil }
        return fieldError?.message
    }

    private func clearFieldError(for field: SubTrackInputField) {
        if fieldError?.field == field {
            fieldError = nil
        }
    }

    private func requestClose() {
        if dirty { confirmDiscard = true } else { dismiss() }
    }

    private func save() {
        fieldError = nil
        errorMessage = ""
        do {
            try model.saveSubscription(draft.input(), subscription: subscription)
            dismiss()
        } catch SubTrackError.invalidInput(let field, let message) {
            fieldError = SubTrackPresentedFieldError(field: field, message: message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
